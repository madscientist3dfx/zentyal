# Copyright (C) 2009-2012 eBox Technologies S.L.
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

# Class: EBox::UsersAndGroups::Model::Mode
#
# This class contains the options needed to enable the usersandgroups module.

package EBox::UsersAndGroups::Model::LdapInfo;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;

use strict;
use warnings;

# Method: _table
#
#	Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{
    my ($self) = @_;

    my @tableDesc = (
        new EBox::Types::Text(
            fieldName => 'dn',
            printableName => __('Base DN'),
        ),
        new EBox::Types::Text (
            fieldName => 'rootDn',
            printableName => __('Root DN'),
        ),
        new EBox::Types::Text (
            fieldName => 'password',
            printableName => __('Password'),
        ),
        new EBox::Types::Text (
            fieldName => 'usersDn',
            printableName => __('Users DN'),
        ),
        new EBox::Types::Text (
            fieldName => 'groupsDn',
            printableName => __('Groups DN'),
        ),
    );

    my $dataForm = {
        tableName           => 'LdapInfo',
        printableTableName  => __('LDAP information'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Users',
    };

    return $dataForm;
}

sub menuFolder
{
    return 'UsersAndGroups';
}

# Method: _content
#
# Overrides:
#
#    <EBox::Model::DataForm::ReadOnly::_content>
#
sub _content
{
    my ($self) = @_;

    my $users = $self->parentModule();

    return {
        dn => $users->ldap()->dn();
        rootDn => $users->ldap()->rootDn();
        password => $users->ldap()->getPassword();
        usersDn => $users->usersDn();
        groupsDn => $users->groupsDn();
    }
}

# Method: precondition
#
#   Check if usersandgroups is enabled.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    return $self->parentModule()->isEnabled();
}

# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail
#
sub preconditionFailMsg
{
    return __('You must enable the Users and Groups module to access the LDAP information.');
}

1;
