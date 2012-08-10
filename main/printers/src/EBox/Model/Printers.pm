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

package EBox::Printers::Model::Printers;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::View::Customizer;
use EBox::Types::Text;
use EBox::Types::HasMany;
use Net::CUPS;

# Group: Public methods

# Constructor: new
#
#       Create the new model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ($self, $class);

    return $self;
}

# Method: viewCustomizer
#
#      Return a custom view customizer to set a permanent message if
#      the VPN is not enabled or configured
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setPermanentMessage($self->_configureMessage());

    return $customizer;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentIds) = @_;

    my $cupsPrinters = $self->cupsPrinters();
    my %cupsPrinters = map { $_->getName() => $_ } @{$cupsPrinters};
    my %currentPrinters =
        map { $self->row($_)->valueByName('printer') => 1 } @{$currentIds};

    my $modified = 0;

    foreach my $printerName (keys %cupsPrinters) {
        next if exists $currentPrinters{$printerName};
        my $p = $cupsPrinters{$printerName};
        my $desc = $p->getDescription();
        my $loc = $p->getLocation();
        $self->add(printer => $printerName, description => $desc,
                   location => $loc, guest => 0);
        $modified = 1;
    }

    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        my $printerName = $row->valueByName('printer');
        next if exists $cupsPrinters{$printerName};
        $self->removeRow($id);
        $modified = 1;
    }

    EBox::Global->modChange('samba') if ($modified);

    return $modified;
}

sub cupsPrinters
{
    my ($self) = @_;

    my $cups = Net::CUPS->new();
    my @printers = $cups->getDestinations();
    return \@printers;
}

# Method: precondition
#
# Overrides:
#
#      <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $modEnabled = $self->parentModule()->isEnabled();
    my $fs = EBox::Config::configkey('samba-fs');
    my $s3fs = (defined $fs and $fs eq 's3fs');

    return ($modEnabled and $s3fs);
}

# Method: preconditionFailMsg
#
# Overrides:
#
#      <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;

    my $modEnabled = $self->parentModule()->isEnabled();
    unless ($modEnabled) {
        return __x('Prior to configure printers ACLs you need to enable '
                   . 'the module in the {openref}Module Status{closeref} '
                   . ' section and save changes after that.',
                   openref => '<a href="/ServiceModule/StatusView">',
                   closeref => '</a>');
    }

    my $fs = EBox::Config::configkey('samba_fs');
    my $s3fs = (defined $fs and $fs eq 's3fs');
    unless ($s3fs) {
        return __("You are using the new samba 'ntvfs' file server, " .
                  "which is incompatible with the printing service. " .
                  "If you wish to enable this feature, add " .
                  "the Zentyal PPA to your APT sources.list and install " .
                  "our samba4 package, then change the samba config key " .
                  "'samba_fs' to 's3fs' in /etc/zentyal/samba.conf");
    }
}

# Group: Protected methods

sub _table
{
    my ($self) = @_;

    my @tableDesc = (
        new EBox::Types::Text(
            fieldName => 'printer',
            printableName => __('Printer name'),
            unique => 0,
            editable => 0
        ),
        new EBox::Types::Text(
            fieldName => 'description',
            printableName => __('Description'),
            editable => 0,
            optional => 1,
        ),
        new EBox::Types::Text(
            fieldName => 'location',
            printableName => __('Location'),
            editable => 0,
            optional => 1,
        ),
        new EBox::Types::Boolean(
            fieldName     => 'guest',
            printableName => __('Guest access'),
            editable      => 1,
            defaultValue  => 0,
            help          => __('This printer will not require authentication.'),
        ),
        new EBox::Types::HasMany(
            fieldName     => 'access',
            printableName => __('Access control'),
            foreignModel => 'PrinterPermissions',
            view => '/Printers/View/PrinterPermissions'
        ),
    );

    my $dataForm =
    {
        tableName          => 'Printers',
        printableTableName => __('Printer permissions'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        modelDomain        => 'Printers',
        sortedBy           => 'printer',
        printableRowName   => __('printer'),
        withoutActions     => 1,
        help               => __('Here you can define the access control list for your printers.'),
    };
    return $dataForm;
}

sub _configureMessage
{
    my ($self) = @_;

    my $CUPS_PORT = 631;
    my $URL = "https://localhost:$CUPS_PORT/admin";
    my $message = __x('To add or manage printers you have to use the {open_href}CUPS Web Interface{close_href}',
                      open_href => "<a href='$URL' target='_blank' id='cups_url'>",
                      close_href => '</a>');
    $message .= "<script>document.getElementById('cups_url').href='https://' + document.domain + ':$CUPS_PORT/admin';</script>";

    return $message;
}

1;
