package Bugzilla::DaemonControl;
use 5.10.1;
use strict;
use warnings;

use Cwd qw(realpath);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir catfile);
use English qw(-no_match_vars $PROGRAM_NAME);
use Future;
use Future::Utils qw(repeat try_repeat);
use IO::Async::Loop;
use IO::Async::Process;
use IO::Async::Signal;
use IO::Async::Protocol::LineStream;
use LWP::Simple qw(get);
use POSIX qw(setsid WEXITSTATUS);
use WWW::Selenium::Util qw(server_is_running);

use base qw(Exporter);

our @EXPORT_OK = qw(
    run_httpd run_cereal run_cereal_and_httpd
    catch_signal on_finish on_exception
    assert_httpd assert_database assert_selenium
);

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
    run => [grep { /^run_/ } @EXPORT_OK],
    utils => [qw(catch_signal on_exception on_finish)],
);

use constant CONF_DIR => realpath(catdir(dirname(__FILE__), '..', 'conf'));
use constant HTTPD_BIN     => '/usr/sbin/httpd';
use constant HTTPD_CONFIG  => catfile( CONF_DIR, 'httpd.conf' );

sub catch_signal {
    my ($name, @done)   = @_;
    my $loop     = IO::Async::Loop->new;
    my $signal_f = $loop->new_future;
    my $signal   = IO::Async::Signal->new(
        name       => $name,
        on_receipt => sub {
            $signal_f->done(@done);
        }
    );
    $signal_f->on_cancel(
        sub {
            my $l = IO::Async::Loop->new;
            $l->remove($signal);
        },
    );

    $loop->add($signal);

    return $signal_f;
}

sub cereal {
    $PROGRAM_NAME = "cereal";
    my $loop = IO::Async::Loop->new;
    $loop->listen(
        host => '127.0.0.1',
        service => '5880',
        socktype => 'stream',
        on_stream => sub {
            my ($stream) = @_;
            my $protocol = IO::Async::Protocol::LineStream->new(
                transport => $stream,
                on_read_line => sub {
                    my ($self, $line) = @_;
                    say $line;
                },
            );
            $loop->add($protocol);
        },
    )->get;
    kill 'USR1', getppid();

    exit catch_signal('TERM', 0)->get;
}

sub run_cereal {
    my $loop   = IO::Async::Loop->new;
    my $exit_f = $loop->new_future;
    my $cereal = IO::Async::Process->new(
        code         => \&cereal,
        on_finish    => on_finish($exit_f),
        on_exception => on_exception( "cereal", $exit_f ),
    );
    $exit_f->on_cancel( sub { $cereal->kill('TERM') } );
    $loop->add($cereal);
    catch_signal('USR1')->get;

    return $exit_f;
}

sub run_httpd {
    my (@args) = @_;
    my $loop = IO::Async::Loop->new;

    my $exit_f = $loop->new_future;
    my $httpd  = IO::Async::Process->new(
        code => sub {
            # we have to setsid() to make a new process group
            # or else apache will kill its parent.
            setsid();
            exec HTTPD_BIN, '-DFOREGROUND', '-f' => HTTPD_CONFIG, @args;
        },
        on_finish    => on_finish($exit_f),
        on_exception => on_exception( 'httpd', $exit_f ),
    );
    $exit_f->on_cancel( sub { $httpd->kill('TERM') } );
    $loop->add($httpd);

    return $exit_f;
}

sub run_cereal_and_httpd {
    my @httpd_args = @_;

    my $lc = Bugzilla::Install::Localconfig::read_localconfig();
    if ( ($lc->{inbound_proxies} // '') eq '*' && $lc->{urlbase} =~ /^https/) {
        push @httpd_args, '-DHTTPS';
    }
    push @httpd_args, '-DNETCAT_LOGS';
    my $cereal_exit_f = run_cereal();
    my $signal_f      = catch_signal("TERM", 0);
    my $httpd_exit_f  = run_httpd(@httpd_args);
    Future->wait_any($cereal_exit_f, $httpd_exit_f, $signal_f);
}

sub delay_future_value {
    my (%param) = @_;
    my $loop = IO::Async::Loop->new;
    my $value = delete $param{value};
    return $loop->delay_future(%param)->then(sub { $loop->new_future->done($value) });
}

sub assert_httpd {
    my $loop = IO::Async::Loop->new;
    my $port  = $ENV{PORT} // 8000;
    my $repeat = repeat {
        $loop->delay_future(after => 0.25)->then(
            sub {
                Future->wrap(get("http://localhost:$port/__lbheartbeat__") // '');
            },
        );
    } until => sub {
        my $f = shift;
        ( $f->get =~ /^httpd OK/ );
    };
    my $timeout = $loop->timeout_future(after => 20)->else_fail("assert_httpd timeout");
    return Future->wait_any($repeat, $timeout);
}

sub assert_selenium {
    my $loop = IO::Async::Loop->new;
    my $port  = $ENV{PORT} // 8000;
    my $repeat = repeat {
        $loop->delay_future(after => 1)->then(
            sub {
                my $ok = server_is_running() ? 1 : 0;
                warn "no selenium\n" unless $ok;
                Future->wrap($ok)
            },
        );
    } until => sub { shift->get };
    my $timeout = $loop->timeout_future(after => 60)->else_fail("assert_selenium timeout");
    return Future->wait_any($repeat, $timeout);
}

sub assert_database {
    my $loop = IO::Async::Loop->new;
    my $lc   = Bugzilla::Install::Localconfig::read_localconfig();

    for my $var (qw(db_name db_host db_user db_pass)) {
        return $loop->new_future->die("$var is not set!") unless $lc->{$var};
    }

    my $dsn    = "dbi:mysql:database=$lc->{db_name};host=$lc->{db_host}";
    my $repeat = repeat {
        $loop->delay_future( after => 0.25 )->then(
            sub {
                my $dbh = DBI->connect(
                    $dsn,
                    $lc->{db_user},
                    $lc->{db_pass},
                    { RaiseError => 0, PrintError => 0 },
                );
                Future->wrap($dbh);
            }
        );
    }
    until => sub { defined shift->get };
    my $timeout = $loop->timeout_future( after => 20 )->else_fail("assert_database timeout");
    my $any_f = Future->needs_any( $repeat, $timeout );
    return $any_f->transform(
        done => sub { return },
        fail => sub { "unable to connect to $dsn as $lc->{db_user}" },
    );
}

sub on_finish {
    my ($f) = @_;
    return sub {
        my ($self, $exitcode) = @_;
        $f->done(WEXITSTATUS($exitcode));
    };
}

sub on_exception {
    my ( $name, $f ) = @_;
    return sub {
        my ( $self, $exception, $errno, $exitcode ) = @_;

        if ( length $exception ) {
            $f->fail( "$name died with the exception $exception " . "(errno was $errno)\n" );
        }
        elsif ( ( my $status = WEXITSTATUS($exitcode) ) == 255 ) {
            $f->fail("$name failed to exec() - $errno\n");
        }
        else {
            $f->fail("$name exited with exit status $status\n");
        }
    };
}

1;