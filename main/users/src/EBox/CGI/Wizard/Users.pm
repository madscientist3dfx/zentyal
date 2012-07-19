# Copyright (C) 2010-2012 eBox Technologies S.L.
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

package EBox::CGI::UsersAndGroups::Wizard::Users;

use strict;
use warnings;

use base 'EBox::CGI::WizardPage';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use Error qw(:try);

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => 'users/wizard/users.mas', @_);
    bless ($self, $class);
    return $self;
}

sub _processWizard
{
    my ($self) = @_;

    my $domain = $self->param('domain');
    if ($domain) {
        EBox::info('Setting the host domain');

        # Write the domain to sysinfo model
        my $sysinfo = EBox::Global->modInstance('sysinfo');
        my $domainModel = $sysinfo->model('HostName');
        my $row = $domainModel->row();
        $row->elementByName('hostdomain')->setValue($domain);
        $row->store();
    }
}

1;
