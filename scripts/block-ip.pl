
#!/usr/bin/perl

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use strict;
use warnings;
use lib qw(. lib local/lib/perl5);

use Bugzilla;
use Bugzilla::Constants;
use Bugzilla::ModPerl::BlockIP;
use Getopt::Long;

Bugzilla->usage_mode(USAGE_MODE_CMDLINE);

my $unblock;
GetOptions('unblock' => \$unblock);

if ($unblock) {
    Bugzilla::ModPerl::BlockIP->unblock_ip($_) for @ARGV;
} else {
    Bugzilla::ModPerl::BlockIP->block_ip($_) for @ARGV;
}

