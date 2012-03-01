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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::UsersAndGroups::Model::SlavePassword
#
#   Next password to use on slave registering
#

package EBox::UsersAndGroups::Model::SlavePassword;

use EBox::Gettext;
use EBox::Types::Text;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my @tableHead =
    (
        new EBox::Types::Text(
            'fieldName' => 'password',
            'printableName' => __('Slave connection password'),
            'unique' => 1,
        ),
    );
    my $dataTable =
    {
        'tableName' => 'SlavePassword',
        'printableTableName' => __('Password'),
        'modelDomain' => 'Users',
        'tableDescription' => \@tableHead,
        'help' => __('Use this password when connecting a new slave to this server.'),
    };

    return $dataTable;
}

1;
