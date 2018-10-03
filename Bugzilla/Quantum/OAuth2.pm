package Bugzilla::Quantum::OAuth2;

use 5.10.1;
use Moo;

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::Error;
use Bugzilla::Logging;
use Bugzilla::Util;

use DateTime;

use base qw(Exporter);
our @EXPORT_OK = qw(oauth2);

sub oauth2 {
    my ( $self ) = @_;

    $self->plugin(
        'OAuth2::Server' => {
            login_resource_owner      => \&_resource_owner_logged_in,
            confirm_by_resource_owner => \&_resource_owner_confirm_scopes,
            verify_client             => \&_verify_client,
            store_auth_code           => \&_store_auth_code,
            verify_auth_code          => \&_verify_auth_code,
            store_access_token        => \&_store_access_token,
            verify_access_token       => \&_verify_access_token,
        }
    );

    # Manage the client list
    my $r = $self->routes;
    my $client_route = $r->under('/admin/oauth' => sub {
        my ($c) = @_;
        my $user = $c->bugzilla->login(LOGIN_REQUIRED) || return undef;
        $user->in_group('admin')
            || ThrowUserError("auth_failure", {group  => "admin",
                                               action => "edit",
                                               object => "oauth_clients"});
        return 1;
    });
    $client_route->any('/list')->to( 'OAuth2::Clients#list' )->name('list_clients');
    $client_route->any('/create')->to( 'OAuth2::Clients#create' )->name('create_client');
    $client_route->any('/delete')->to( 'OAuth2::Clients#delete' )->name('delete_client');
    $client_route->any('/edit')->to( 'OAuth2::Clients#edit' )->name('edit_client');

    return 1;
}

sub _resource_owner_logged_in {
    my ( %args ) = @_;
    my $c = $args{mojo_controller};

    my $user = $c->bugzilla->login(LOGIN_REQUIRED) || return undef;

    if ( !$user->user->id ) {
        # we need to redirect back to the /oauth/authorize route after
        # login (with the original params)
        my $uri = join( '?', $c->url_for('current'), $c->url_with->query );
        $c->flash( 'redirect_after_login' => $uri );
        $c->redirect_to('/login');
        return 0;
    }

    return 1;
}

sub _resource_owner_confirm_scopes {
    my ( %args ) = @_;
    my ( $c, $client_id, $scopes_ref ) = @args{qw/ mojo_controller client_id scopes /};

    my $is_allowed = $c->flash("oauth_${client_id}");

    # if user hasn't yet allowed the client access, or if they denied
    # access last time, we check [again] with the user for access
    if ( !$is_allowed ) {
        $c->flash( client_id => $client_id );
        $c->flash( scopes    => $scopes_ref );

        my $uri = join( '?', $c->url_for('current'), $c->url_with->query );
        $c->flash( 'redirect_after_login' => $uri );
        $c->redirect_to('/oauth/confirm_scopes');
    }

    return $is_allowed;
}

sub _verify_client {
    my ( %args ) = @_;
    my ( $c, $client_id, $scopes_ref ) = @args{qw/ mojo_controller client_id scopes /};
    my $dbh = Bugzilla->dbh;

    if ( my $client_data = $dbh->selectrow_hashref( "SELECT * FROM oauth2_client WHERE id = ?", undef, $client_id ) ) {
        if ( !$client_data->{active} ) {
            INFO("Client ($client_id) is not active");
            return ( 0, 'unauthorized_client' );
        }

        foreach my $rqd_scope ( @{ $scopes_ref // [] } ) {
            my $scope_allowed = $dbh->selectrow_array(
                "SELECT allowed FROM oauth2_client_scope
                   JOIN oauth2_scope ON oauth2_scope.id = oauth2_client_scope.scope_id
                  WHERE client_id = ? AND oauth2_scope.description = ?",
                undef, $client_id, $rqd_scope
            );
            if ( defined $scope_allowed ) {
                if ( !$scope_allowed ) {
                    INFO("Client disallowed scope ($rqd_scope)");
                    return ( 0, 'access_denied' );
                }
            }
            else {
                INFO("Client lacks scope ($rqd_scope)");
                return ( 0, 'invalid_scope' );
            }
        }

        return (1);
    }

    INFO("Client ($client_id) does not exist");
    return ( 0, 'unauthorized_client' );
}

sub _store_auth_code {
    my ( %args ) = @_;
    my ( $c, $auth_code, $client_id, $expires_in, $uri, @scopes )
        = @args{qw/ mojo_controller auth_code client_id expires_in redirect_uri scopes /};
    my $dbh = Bugzilla->dbh;

    my $user_id = Bugzilla->user->id;

    $dbh->do( "INSERT INTO oauth2_auth_code VALUES (?, ?, ?, ?, ?, 0)",
        undef, $auth_code, $client_id, Bugzilla->user->id, DateTime->from_epoch( epoch => time + $expires_in ), $uri );

    foreach my $rqd_scope (@scopes) {
        my $scope_id = $dbh->selectrow_array( "SELECT id FROM oauth2_scope WHERE description = ?", undef, $rqd_scope );
        if ($scope_id) {
            $dbh->do( "INSERT INTO oauth2_auth_code_scope VALUES (?, ?, 1)", undef, $auth_code, $scope_id );
        }
        else {
            ERROR("Unknown scope ($rqd_scope) in _store_auth_code");
        }
    }

    return;
}

sub _verify_auth_code {
    my ( %args ) = @_;
    my ( $c, $client_id, $client_secret, $auth_code, $uri )
        = @args{qw/ mojo_controller client_id client_secret auth_code redirect_uri /};
    my $dbh = Bugzilla->dbh;

    my $client_data = $dbh->selectrow_hashref( "SELECT * FROM oauth2_client WHERE client_id = ?", undef, $client_id );
    $client_data || return ( 0, 'unauthorized_client' );

    my $auth_code_data
        = $dbh->selectrow_hashref( "SELECT * FROM oauth2_auth_code WHERE client_id = ? AND auth_code = ?",
        undef, $client_id, $auth_code );

    if (  !$auth_code_data
        or $auth_code_data->{verified}
        or ( $uri ne $auth_code_data->{redirect_uri} )
        or ( $auth_code_data->{expires} <= time )
        or !_check_password( $client_secret, $client_data->{secret} ) )
    {
        INFO("Auth code does not exist")
            if !$auth_code;
        INFO("Client secret does not match")
            if !_check_password( $client_secret, $client_data->{secret} );

        if ($auth_code) {
            INFO("Client secret does not match")
                if ( $uri && $auth_code_data->{redirect_uri} ne $uri );
            INFO("Auth code expired")
                if ( $auth_code_data->{expires} <= time );

            if ( $auth_code_data->{verified} ) {

                # the auth code has been used before - we must revoke the auth code
                # and any associated access tokens (same client_id and user_id)
                INFO( "Auth code already used to get access token, " . "revoking all associated access tokens" );
                $dbh->do( "DELETE FROM oauth2_auth_code WHERE auth_code = ?", undef, $auth_code );

                if (my $access_tokens = $dbh->selectall_arrayref(
                        "SELECT * FROM oauth2_access_token WHERE client_id = ? AND user_id = ?",
                        { Slice => {} },
                        $client_id, $auth_code_data->{user_id}
                    )
                    )
                {
                    foreach my $access_token ( @{$access_tokens} ) {
                        $dbh->do( "DELETE FROM oauth2_access_token WHERE client_id = ? AND user_id = ?",
                            undef, $client_id, $auth_code_data->{user_id} );
                    }
                }
            }
        }

        return ( 0, 'invalid_grant' );
    }

    $dbh->do( "UPDATE oauth2_auth_code SET verified = 1 WHERE auth_code = ?", undef, $auth_code );

    # scopes are those that were requested in the authorization request, not
    # those stored in the client (i.e. what the auth request restriced scopes
    # to and not everything the client is capable of)
    my $scope_descriptions = $dbh->selectrow_array(
        "SELECT oauth2_scope.description FROM oauth2_scope
          JOIN oauth2_scope ON oauth2_scope.id = oauth2_auth_code_scope.scope_id
         WHERE oauth2_auth_code_scope.auth_code = ?",
        undef, $auth_code
    );

    my %scope = map { $_ => 1 } @{$scope_descriptions};

    return ( $client_id, undef, {%scope}, $auth_code_data->{user_id} );
}

sub _check_password {
    my ( $hashed_password, $password ) = @_;
    return $hashed_password eq $password ? 1 : 0;
}

sub _store_access_token {
    my ( %args ) = @_;
    my ( $c, $client, $auth_code, $access_token, $refresh_token, $expires_in, $scope, $old_refresh_token )
        = @args{qw/ mojo_controller client_id auth_code access_token refresh_token expires_in scope old_refresh_token /
        };
    my $dbh = Bugzilla->dbh;
    my ($user_id);

    if ( !defined($auth_code) && $old_refresh_token ) {

        # must have generated an access token via a refresh token so revoke the
        # old access token and refresh token (also copy required data if missing)
        my $prev_refresh_token = $dbh->selectrow_hashref( "SELECT * FROM oauth2_refresh_token WHERE refresh_token = ?",
            undef, $old_refresh_token );
        my $prev_access_token = $dbh->selectrow_hashref( "SELECT * FROM oauth2_access_token WHERE access_token = ?",
            undef, $prev_refresh_token->{access_token} );

        # access tokens can be revoked, whilst refresh tokens can remain so we
        # need to get the data from the refresh token as the access token may
        # no longer exist at the point that the refresh token is used
        my $scope_descriptions = $dbh->selectall_array(
            "SELECT oauth2_scope.description FROM oauth2_scope JOIN oauth2_access_token_scope ON scope.id = oauth2_access_token_scope.scope_id WHERE access_token = ?",
            undef, $old_refresh_token
        );
        $scope //= { map { $_ => 1 } @{$scope_descriptions} };

        $user_id = $prev_refresh_token->{user_id};
    }
    else {
        $user_id
            = $dbh->selectrow_array( "SELECT user_id FROM oauth2_auth_code WHERE auth_code = ?", undef, $auth_code );
    }

    if ( ref($client) ) {
        $scope   //= $client->{scope};
        $user_id //= $client->{user_id};
        $client = $client->{client_id};
    }

    foreach my $token_type (qw/ access refresh /) {
        my $table = "oauth2_${token_type}_token";

        # if the client has en existing access/refresh token we need to revoke it
        $dbh->do( "DELETE FROM $table WHERE client_id = ? AND user_id = ?", undef, $client, $user_id );
    }

    $dbh->do( "INSERT INTO oauth2_access_token VALUES (?, ?, ?, ?, ?)",
        undef, $access_token, $refresh_token, $client, Bugzilla->user->id,
        DateTime->from_epoch( epoch => time + $expires_in ) );

    $dbh->do( "INSERT INTO oauth2_refresh_token VALUES (?, ?, ?, ?)",
        undef, $refresh_token, $access_token, $client, Bugzilla->user->id );

    foreach my $rqd_scope ( keys( %{$scope} ) ) {
        my $db_scope = $dbh->selectrow_array( "SELECT id FROM oauth2_scope WHERE description = ?", undef, $rqd_scope );
        if ($db_scope) {
            foreach my $related (qw/ access_token refresh_token /) {
                my $table = "oauth2_${related}_scopes";
                $dbh->do(
                    "INSERT INTO $table VALUES (?, ?, ?)",
                    undef, $related eq 'access_token' ? $access_token : $refresh_token,
                    $db_scope, $scope->{$rqd_scope}
                );
            }
        }
        else {
            ERROR("Unknown scope ($rqd_scope) in _store_access_token");
        }
    }

    return;
}

sub _verify_access_token {
    my ( %args ) = @_;
    my ( $c, $access_token, $scopes_ref ) = @args{qw/ mojo_controller access_token scope /};
    my $dbh = Bugzilla->dbh;

    if ( my $refresh_token_data
        = $dbh->selectrow_hashref( "SELECT * FROM oauth2_refresh_token WHERE access_token = ?", undef, $access_token ) )
    {
        foreach my $scope ( @{ $scopes_ref // [] } ) {
            my $scope_allowed = $dbh->selectrow_array(
                "SELECT allowed FROM oauth2_refresh_token_scope
                   JOIN oauth2_scope ON oauth2_scope.id = oauth2_refresh_token_scope.scope_id
                  WHERE refresh_token = ? AND oauth2_scope.description = ?",
                undef, $access_token, $scope
            );

            if ( !defined $scope_allowed || !$scope_allowed ) {
                INFO("Refresh token doesn't have scope ($scope)");
                return ( 0, 'invalid_grant' );
            }
        }

        return $refresh_token_data->{client_id};

    }
    elsif ( my $access_token_data
        = $dbh->selectrow_hashref( "SELECT * FROM oauth2_access_token WHERE access_token = ?", undef, $access_token ) )
    {
        if ( $access_token_data->{expires} <= time ) {
            INFO("Access token has expired");
            $dbh->do( "DELETE FROM oauth2_access_token WHERE access_token = ?", undef, $access_token );
            return ( 0, 'invalid_grant' );
        }

        foreach my $scope ( @{ $scopes_ref // [] } ) {

            my $db_scope_allowed = $dbh->selectrow_array(
                "SELECT allowed FROM oauth2_access_token_scope JOIN oauth2_scope ON oauth2_access_token_scope.scope_id = oauth2_scope.id
                 WHERE scope.description = ? AND access_token = ?", undef, $scope, $access_token
            );
            if ( !defined $db_scope_allowed || !$db_scope_allowed ) {
                INFO("Access token doesn't have scope ($scope)");
                return ( 0, 'invalid_grant' );
            }
        }

        return {
            client_id => $access_token_data->{client_id},
            user_id   => $access_token_data->{user_id},
        };

    }
    else {
        INFO("Access token does not exist");
        return ( 0, 'invalid_grant' );
    }

}

1;
