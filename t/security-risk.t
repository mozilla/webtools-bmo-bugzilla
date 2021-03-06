#!/usr/bin/env perl
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.
use strict;
use warnings;
use 5.10.1;
use lib qw( . lib local/lib/perl5 );
use Bugzilla;

BEGIN { Bugzilla->extensions }

use JSON::MaybeXS;
use Test::More;
use Test2::Tools::Mock;
use Try::Tiny;

use Bugzilla::Test::MockParams (report_secbugs_teams => "Frontend\nBackend");

use ok 'Bugzilla::Report::SecurityRisk';
can_ok('Bugzilla::Report::SecurityRisk', qw(new results));

my $SecurityRisk = mock 'Bugzilla::Report::SecurityRisk' => (
  override => [
    _build_team_info => sub {
      return {
        Frontend => {Firefox => ['ComponentA'],},
        Backend  => {Core    => ['ComponentB'],}
      };
    }
  ]
);

sub check_open_state_mock {
  my ($state) = @_;
  return grep {/^$state$/} qw(UNCOMFIRMED NEW ASSIGNED REOPENED);
}

try {
  use Bugzilla::Report::SecurityRisk;
  my $teams = [split /\n/, Bugzilla->params->{report_secbugs_teams}];
  my $report = Bugzilla::Report::SecurityRisk->new(
    start_date => DateTime->new(year => 2000, month => 1, day => 9),
    end_date   => DateTime->new(year => 2000, month => 1, day => 16),
    sec_keywords     => ['sec-critical', 'sec-high'],
    teams            => $teams,
    check_open_state => \&check_open_state_mock,
    very_old_days    => 45,
    initial_bug_ids  => [1, 2, 3, 4],
    initial_bugs     => {
      1 => {
        id         => 1,
        product    => 'Firefox',
        component  => 'ComponentA',
        team       => 'Frontend',
        sec_level  => 'sec-high',
        status     => 'RESOLVED',
        is_open    => 0,
        is_stalled => 0,
        created_at => DateTime->new(year => 2000, month => 1, day => 1),
      },
      2 => {
        id         => 2,
        product    => 'Core',
        component  => 'ComponentB',
        team       => 'Backend',
        sec_level  => 'sec-critical',
        status     => 'RESOLVED',
        is_open    => 0,
        is_stalled => 0,
        created_at => DateTime->new(year => 2000, month => 1, day => 1),
      },
      3 => {
        id         => 3,
        product    => 'Core',
        component  => 'ComponentB',
        team       => 'Backend',
        sec_level  => 'sec-high',
        status     => 'ASSIGNED',
        is_open    => 1,
        is_stalled => 0,
        created_at => DateTime->new(year => 2000, month => 1, day => 5),
      },
      4 => {
        id         => 4,
        product    => 'Firefox',
        component  => 'ComponentA',
        team       => 'Frontend',
        sec_level  => 'sec-critical',
        status     => 'ASSIGNED',
        is_open    => 1,
        is_stalled => 0,
        created_at => DateTime->new(year => 2000, month => 1, day => 10),
      },
    },
    events => [

      # Canned event's should be in reverse chronological order.
      {
        bug_id     => 2,
        bug_when   => DateTime->new(year => 2000, month => 1, day => 14),
        field_name => 'keywords',
        removed    => '',
        added      => 'sec-critical',

      },
      {
        bug_id     => 1,
        bug_when   => DateTime->new(year => 2000, month => 1, day => 12),
        field_name => 'bug_status',
        removed    => 'ASSIGNED',
        added      => 'RESOLVED',
      },
    ],
  );
  my $actual_results   = $report->results;
  my $expected_results = [
    {
      date         => DateTime->new(year => 2000, month => 1, day => 9),
      bugs_by_team => {
        'Frontend' => {

          # Rewind the event that caused 1 to close.
          open            => [1],
          closed          => [],
          very_old_bugs   => []
        },
        'Backend' => {

          # 2 wasn't a sec-critical bug on the report date.
          open            => [3],
          closed          => [],
          very_old_bugs   => []
        }
      },
      bugs_by_sec_keyword => {
        'sec-critical' => {

          # 2 wasn't a sec-critical bug and 4 wasn't created yet on the report date.
          open            => [],
          closed          => [],
          very_old_bugs   => []
        },
        'sec-high' => {

          # Rewind the event that caused 1 to close.
          open            => [1, 3],
          closed          => [],
          very_old_bugs   => []
        }
      },
    },
    {    # The report on 2000-01-16 matches the state of initial_bugs.
      date         => DateTime->new(year => 2000, month => 1, day => 16),
      bugs_by_team => {
        'Frontend' => {open => [4], closed => [1], very_old_bugs => []},
        'Backend'  => {open => [3], closed => [2], very_old_bugs => []}
      },
      bugs_by_sec_keyword => {
        'sec-critical' => {open => [4], closed => [2], very_old_bugs => []},
        'sec-high'     => {open => [3], closed => [1], very_old_bugs => []}
      },
    },
  ];

  is_deeply($actual_results, $expected_results, 'Report results are accurate');

}
catch {
  fail('got an exception during main part of test');
  diag($_);
};

done_testing;
