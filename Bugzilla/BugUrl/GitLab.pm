# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::BugUrl::GitLab;

use 5.10.1;
use strict;
use warnings;

use base qw(Bugzilla::BugUrl);

###############################
####        Methods        ####
###############################

sub should_handle {
  my ($class, $uri) = @_;

# GitLab issue URLs can have the form:
# https://gitlab.com/projectA/subprojectB/subprojectC/../issues/53
  return (lc($uri->authority) eq 'gitlab.com'
      and $uri->path =~ m!^/.*/issues/\d+$!) ? 1 : 0;
}

sub _check_value {
  my ($class, $uri) = @_;

  $uri = $class->SUPER::_check_value($uri);

  # Require the HTTPS scheme.
  $uri->scheme('https');

  return $uri;
}

1;
