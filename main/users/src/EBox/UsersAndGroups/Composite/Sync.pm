# Copyright (C) 2010-2011 eBox Technologies S.L.
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

# Class: EBox::UsersAndGroups::Composite::Sync;

package EBox::UsersAndGroups::Composite::Sync;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Constructor: new
#
#         Constructor for the Sync composite
#
sub new
{
      my ($class) = @_;

      my $self = $class->SUPER::new();

      return $self;
}

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
{
      my $users = EBox::Global->modInstance('users');

      my $description =
        {
         components      => [ 'Master', 'SlavePassword', 'Slaves' ],
         layout          => 'top-bottom',
         name            => 'Sync',
         compositeDomain => 'Users',
         help =>
             __('')
        };

      return $description;
}

sub pageTitle
{
    return __('Users synchronization');
}

sub menuFolder
{
    return 'UsersAndGroups';
}


# Method: precondition
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
sub precondition
{
    my ($self) = @_;
    my $usersMod = EBox::Global->modInstance('users');
    unless ($usersMod->configured()) {
        return undef;
    }

    return 1;
}

# Method: preconditionFailMsg
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
sub preconditionFailMsg
{
    my ($self) = @_;

    return __('You must enable the module Users in the module ' .
              'status section in order to use it.');
}


1;
