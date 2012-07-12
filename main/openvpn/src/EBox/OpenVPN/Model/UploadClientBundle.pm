# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::OpenVPN::Model::UploadClientBundle;
use base 'EBox::Model::DataForm::Action';

use strict;
use warnings;

use Error qw(:try);

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::Select;
use EBox::Types::Host;
use EBox::Types::Password;
use EBox::Types::File;
use EBox::Types::Port;
use EBox::Types::HostIP;

use EBox::OpenVPN::Types::PortAndProtocol;
use EBox::OpenVPN::Client::ValidateCertificate;

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
    my @tableHead = (
         new EBox::Types::File(
                               fieldName => 'configurationBundle',
                               printableName =>
                                  __(q{Upload configuration bundle}),
                               editable => 1,
                               dynamicPath => \&_bundlePath,
                              ),
        );

    my $dataTable =
        {
            'tableName'               => __PACKAGE__->nameFromClass(),
            'printableTableName' => __('Upload client configuration bundle'),
            'automaticRemove' => 1,
            'defaultController' => '/OpenVPN/Controller/UploadClientBundle',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('client'),
            'modelDomain' => 'OpenVPN',
        };

    return $dataTable;
}



sub name
{
    __PACKAGE__->nameFromClass(),
}

sub _bundlePath
{
    my ($file) = @_;
    return unless (defined($file));
    return unless (defined($file->model()));

    my $row     = $file->row();
    return unless defined $row;

    my $clientName = __PACKAGE__->_clientName($row);
    $clientName or
        return;

    return EBox::Config::tmp() . "$clientName.bundle";
}

sub formSubmitted
{
    my ($self, $row) = @_;
    my $bundleField  = $row->elementByName('configurationBundle');

    my $clientName = __PACKAGE__->_clientName($row);
    my $bundle = $bundleField->tmpPath();
    my $openvpn = EBox::Global->modInstance('openvpn');
    try {
        $openvpn->setClientConfFromBundle($clientName, $bundle);
    }
    finally {
        if (-f $bundle) {
            unlink $bundle;
        }
    };
}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
sub pageTitle
{
    my ($self) = @_;

    my $name = $self->parentRow()->printableValueByName('name');
    return __x('Upload configuration bundle for {na}', na => $name);
}

sub _clientName
{
    my ($package, $row) = @_;

    my $parent  = $row->parentRow();

    $parent or
        return undef;

    return $parent->elementByName('name')->value();
}

1;
