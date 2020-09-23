# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

package Bugzilla::Auth::Login::OAuth2;

use 5.10.1;
use strict;
use warnings;

use base qw(Bugzilla::Auth::Login);

use Bugzilla::Constants;
use Bugzilla::Error;

use Mojo::UserAgent;

use constant can_logout            => 0;
use constant can_login             => 0;
use constant requires_verification => 0;
use constant is_automatic          => 1;

sub get_login_info {
  my ($self) = @_;
  my $cache  = Bugzilla->request_cache;
  my $params = Bugzilla->params;

  my $userinfo = $cache->{oauth2_client_userinfo};
  if (!$params->{oauth2_client_enabled} || !$userinfo) {
    return {failure => AUTH_NODATA}
  }

  if ($userinfo->{email} && $userinfo->{email_verified}) {
    return {username => $userinfo->{email}, realname => $userinfo->{name}};
  }

  return {failure => AUTH_NODATA}
}

1;
