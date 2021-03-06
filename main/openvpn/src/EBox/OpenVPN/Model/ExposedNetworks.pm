# Copyright (C) 2008-2012 eBox Technologies S.L.
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
use strict;
use warnings;

package EBox::OpenVPN::Model::ExposedNetworks;
use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::Select;

# Group: Public methods

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub name
{
    __PACKAGE__->nameFromClass(),
}

# Group: Protected methods
sub _table
{
    my ($self) = @_;


    my @tableHead =
    (
        new EBox::Types::Select(
                               fieldName     => 'object',
                               foreignModel  => $self->modelGetter('objects', 'ObjectTable'),
                               foreignField  => 'name',
                               foreignNextPageField => 'members',

                               printableName => __('Advertised Network'),
                               unique        => 1,
                               editable      => 1,
                               optional      => 0,
                              ),
    );

    my $dataTable =
        {
            'tableName'              => __PACKAGE__->name(),
            'printableTableName' => __('List of Advertised Networks'),
            'automaticRemove' => 1,
            'defaultController' => '/OpenVPN/Controller/ExposedNetworks',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('Advertised network'),
            'sortedBy' => 'object',
            'modelDomain' => 'OpenVPN',
            'help'  => _help(),
        };

    return $dataTable;
}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
sub pageTitle
{
    my ($self) = @_;
    return $self->parentRow()->printableValueByName('name');
}

# Return the help message
sub _help
{
    return __x('{openpar}You can add here those networks which you want to make ' .
              'available to clients connecting to this VPN.{closepar}' .
              '{openpar}Typically, you will allow access to your LAN by advertising' .
              ' its network address here.{closepar}' .
              '{openpar}If an advertised network address is the same as the VPN' .
              ' network address, the advertised network will be ignored.{closepar}',
              openpar => '<p>', closepar => '</p>');
}

1;
