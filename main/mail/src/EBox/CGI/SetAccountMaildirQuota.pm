# Copyright (C) 2009-2011 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package EBox::CGI::Mail::SetAccountMaildirQuota;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;
use EBox::UsersAndGroups::User;

## arguments:
##      title [required]
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Mail', @_);
    bless($self, $class);
    return $self;
}


sub _process
{
    my ($self) = @_;
    $self->_requireParam('user', __('user'));
    my $user = $self->unsafeParam('user');
    $self->keepParam('user');
    $self->{redirect} = "UsersAndGroups/User?user=$user";

    $self->_requireParam('quotaType');
    my $quotaType = $self->param('quotaType');

    $user = new EBox::UsersAndGroups::User(dn => $user);
    my $mail = EBox::Global->modInstance('mail');
    if ($quotaType eq 'noQuota') {
        $mail->{musers}->setMaildirQuotaUsesDefault($user, 0);
        $mail->{musers}->setMaildirQuota($user, 0);
    } elsif ($quotaType eq 'default') {
        $mail->{musers}->setMaildirQuotaUsesDefault($user, 1);
    } else {
        $self->_requireParam('maildirQuota');
        my $quota = $self->param('maildirQuota');
        if ($quota <= 0) {
            throw EBox::Exceptions::External(
__('Quota must be a amount of MB greter than zero')
               );
        }
        $mail->{musers}->setMaildirQuota($user, $quota);
        $mail->{musers}->setMaildirQuotaUsesDefault($user, 0);
    }
}

1;
