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

package EBox::Printers;

use strict;
use warnings;

use base qw(EBox::Module::Service EBox::FirewallObserver EBox::LogObserver);

use EBox::Gettext;
use EBox::Config;
use EBox::Service;
use EBox::Menu::Item;
use EBox::Sudo;
use EBox::PrinterFirewall;
use EBox::Printers::LogHelper;
use Net::CUPS::Destination;
use Net::CUPS;
use Error qw(:try);

use constant CUPSD => '/etc/cups/cupsd.conf';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'printers',
                                      printableName => __('Printer Sharing'),
                                      @_);
    bless ($self, $class);
    $self->{'cups'} = new Net::CUPS;
    return $self;
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
    {
        'action' => __('Create spool directory for printers'),
        'reason' => __('Zentyal will create a spool directory ' .
                       'under /var/spool/samba'),
        'module' => 'printers'
    },
    {
        'action' => __('Create log table'),
        'reason' => __('Zentyal will create a new table into its log database ' .
                       'to store printers logs'),
        'module' => 'printers'
    },
    {
        'action' => __x('Disable {server} init script', server => 'cups'),
        'reason' => __('Zentyal will take care of start and stop ' .
                       'the service'),
        'module' => 'printers',
    }
    ];
}

# Method: usedFiles
#
#   Override EBox::Module::Service::files
#
sub usedFiles
{
    return [
    {
        'file' => CUPSD,
        'reason' => __('To configure cupsd'),
        'module' => 'printers',
    },
    ];
}

# Method: initialSetup
#
# Overrides:
#
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Execute initial-setup script
    $self->SUPER::initialSetup($version);

    # Add IPP service only if installing the first time
    unless ($version) {
        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->addInternalService(
                            'name' => 'ipp',
                            'printableName' => __('Network Printers'),
                            'description' => __('Internet Printing Protocol (CUPS)'),
                            'protocol' => 'tcp',
                            'sourcePort' => 'any',
                            'destinationPort' => 631,
                           );
        $firewall->saveConfigRecursive();
    }
}

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    # Execute enable-module script
    $self->SUPER::enableActions();

    # Write conf file for the first time using the template,
    # next times only some lines will be overwritten to
    # avoid conflicts with CUPS interface
    $self->writeConfFile(CUPSD, 'printers/cupsd.conf.mas',
                         [ addresses => $self->_ifaceAddresses() ]);
}

sub restoreDependencies
{
    return [ 'network' ];
}

sub firewallHelper
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        return new EBox::PrinterFirewall();
    }
    return undef;
}

sub _preSetConf
{
    my ($self) = @_;

    try {
        # Stop CUPS in order to force it to dump the conf to disk
        $self->stopService();
    } otherwise {};
}

# Method: _setConf
#
#   Override EBox::Module::Base::_setConf
#
sub _setConf
{
    my ($self) = @_;

    $self->_mangleConfFile(CUPSD, addresses => $self->_ifaceAddresses());
}

sub _ifaceAddresses
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');
    my $ifacesModel = $self->model('CUPS');
    my @addresses;
    foreach my $row (@{$ifacesModel->enabledRows()}) {
        my $iface = $ifacesModel->row($row)->valueByName('iface');
        my $iaddresses = $net->ifaceAddresses($iface);
        next unless $iaddresses;
        push (@addresses, map { $_->{address} } @{$iaddresses});
    }

    return \@addresses;
}

sub _mangleConfFile
{
    my ($self, $path, %params) = @_;

    my $newContents = '';
    my @oldContents = File::Slurp::read_file($path);

    foreach my $line (@oldContents) {
        if ($line =~ m{^\s*Listen\s}) {
            # listen statement, removing
            next;
        }  elsif ($line =~ m{^\s*SSLListen\s}) {
            # ssllisten statement, removing
            next;
        } elsif ($line =~m/ by Zentyal,/) {
            # zentyal added skipping
            next;
        }

        $newContents .= $line;
    }

    $newContents .= <<END;
# Added by Zentyal, don't modify or add more Listen/SSLListen statements
Listen localhost:631
Listen /var/run/cups/cups.sock
END
    foreach my $address (@{ $params{addresses} }) {
        $newContents .= "SSLListen $address:631\n";
    }

    EBox::Module::Base::writeFile($path, $newContents);
}

sub _daemons
{
    return [
        {
            'name' => 'cups',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/cups/cupsd.pid'],
        }
    ];
}

sub menu
{
    my ($self, $root) = @_;

    my $item = new EBox::Menu::Item('name' => 'Printers Sharing',
                                    'url' => 'Printers/Composite/General',
                                    'text' => $self->printableName(),
                                    'separator' => 'Office',
                                    'order' => 550);

    $root->add($item);
}

# Method: dumpConfig
#
#   Overrides EBox::Module::Base::dumpConfig
#
sub dumpConfig
{
    my ($self, $dir, %options) = @_;

    $self->stopService();

    my @files = ('/etc/cups/printers.conf', '/etc/cups/ppd');
    my $backupFiles = '';
    foreach my $file (@files) {
        if (EBox::Sudo::fileTest('-e', $file)) {
            $backupFiles .= " $file";
        }
    }
    EBox::Sudo::root("tar cf $dir/etc_cups.tar $backupFiles");

    $self->_startService();
}

# Method: restoreConfig
#
#   Overrides EBox::Module::Base::dumpConfig
#
sub restoreConfig
{
    my ($self, $dir) = @_;

    if (EBox::Sudo::fileTest('-f', "$dir/etc_cups.tar")) {
        try {
            $self->_stopService();
            EBox::Sudo::root("tar xf $dir/etc_cups.tar -C /");
            $self->_startService();
        } otherwise {
            EBox::error("Error restoring cups config from backup");
        };
    } else {
        # This case can happen with old backups
        EBox::warn('Backup doesn\'t contain CUPS configuration files');
    }
}

# Method: networkPrinters
#
#   Returns the printers configured as network printer
#
# Returns:
#
#   array ref - holding the printer id's
#
sub networkPrinters
{
    my ($self) = @_;

    my $cups = Net::CUPS->new();
    my @printers = $cups->getDestinations();
    my $netPrinters = [];
    foreach my $p (@printers) {
        my $uri = $p->getUri();
        my ($proto, $host, $port) =
            ($uri =~ m/(socket|http|ipp|lpd):\/\/([^\/:]+)[^:]*(:[0-9]+)?/);
        next unless ($proto and $host and $port);
        $port =~ s/:// if $port;
        push (@{$netPrinters}, {
            protocol => $proto,
            host => $host,
            port => $port,
        });
    }

    return $netPrinters;
}

# Impelment LogHelper interface

sub tableInfo
{
    my ($self) = @_;

    my $titles = { 'job' => __('Job ID'),
                   'printer' => __('Printer'),
                   'username' => __('User'),
                   'timestamp' => __('Date'),
                   'event' => __('Event')
                 };
    my @order = ('timestamp', 'job', 'printer', 'username', 'event');
    my $events = {
                      'queued' => __('Queued'),
                      'completed' => __('Completed'),
                      'canceled' => __('Canceled'),
                     };

    return [{
             'name' => __('Printers'),
             'tablename' => 'printers_jobs',
             'titles' => $titles,
             'order' => \@order,
             'timecol' => 'timestamp',
             'filter' => ['printer', 'username'],
             'events' => $events,
             'eventcol' => 'event'

            }];
}

sub logHelper
{
    my ($self) = @_;

    return (new EBox::Printers::LogHelper());
}


1;
