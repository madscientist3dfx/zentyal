# Copyright (C) 2011-2012 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::Model::DisasterRecovery
#
# This class is the model to show information about Disaster Recovery service
#
#     - server name
#     - server edition
#     - disaster recovery
#     - remote storage space available
#     - latest configuration backup
#     - latest data backup
#     - data backed up
#     - estimated backup size
#     - estimated time to recover from a disaster
#

package EBox::RemoteServices::Model::DisasterRecovery;

use strict;
use warnings;

use base 'EBox::Model::DataForm::ReadOnly';

use v5.10;

use Date::Calc::Object;
use EBox;
use EBox::Config;
use EBox::Exceptions::NotConnected;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Types::EBoxCommonName;
use EBox::Types::Text;
use POSIX;
use Error qw(:try);

# Constants:
use constant STORE_URL => 'http://store.zentyal.com/';
use constant SB_URL  => STORE_URL . 'small-business-edition/?utm_source=zentyal&utm_medium=disaster_recovery&utm_campaign=smallbusiness_edition';
use constant ENT_URL   => STORE_URL . 'enterprise-edition/?utm_source=zentyal&utm_medium=disaster_recovery&utm_campaign=enterprise_edition';
use constant SUBS_WIZARD_URL => '/Wizard?page=RemoteServices/Wizard/Subscription';

use constant EBACKUP_CONF_FILE => EBox::Config::etc() . 'ebackup.conf';

# Group: Public methods

# Constructor: new
#
#     Create the subscription form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::RemoteServices::Model::DisasterRecovery>
#
sub new
{

    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class);

    return $self;

}
# Method: viewCustomizer
#
#      Return a custom view customizer to set a permanent message if
#      the technical support is not purchased
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
    my $rs = $self->{confmodule};
    my $msg = '';
    unless ( $rs->eBoxSubscribed() ) {
        $msg = _CBmessage();
    }
    my $drOn = 0;
    try {
        $drOn = $rs->disasterRecoveryAddOn();
    } catch EBox::Exceptions::NotConnected with { };
    unless ( $drOn ) {
        $msg .= '<br/><br/>' if ($msg);
        $msg .= _DRmessage();
    }
    $customizer->setPermanentMessage($msg, 'ad') if ($msg);
    return $customizer;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
          new EBox::RemoteServices::Types::EBoxCommonName(
              fieldName     => 'server_name',
              printableName => __('Server name'),
             ),
          new EBox::Types::Text(
              fieldName     => 'edition',
              printableName => __('Server edition'),
             ),
          new EBox::Types::Text(
              fieldName     => 'dr',
              printableName => __('Disaster recovery'),
             ),
          new EBox::Types::Text(
              fieldName     => 'available',
              printableName => __('Remote storage space available'),
             ),
          new EBox::Types::Text(
              fieldName     => 'conf_backup',
              printableName => __('Latest configuration backup'),
             ),
          new EBox::Types::Text(
              fieldName     => 'data_backup',
              printableName => __('Latest data backup'),
             ),
          new EBox::Types::Text(
              fieldName     => 'domains',
              printableName => __('Data backed up'),
             ),
          new EBox::Types::Text(
              fieldName     => 'size',
              printableName => __('Estimated backup size'),
              ),
          new EBox::Types::Text(
              fieldName     => 'eta',
              printableName => __('Estimated time to recover from a disaster'),
             ),
      );

    my $dataForm = {
                    tableName          => __PACKAGE__->nameFromClass(),
                    pageTitle          => __('Disaster Recovery'),
                    modelDomain        => 'RemoteServices',
                    tableDescription   => \@tableDesc,
                    help               => __s('As to the estimated time to recover from a disaster, estimation consists of 45 minutes to install Zentyal server, upper bound of the backup size and average download time obtained from the latest Network report statistics.'),
                };

    return $dataForm;
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

    my $rs = $self->{confmodule};

    my ($serverName, $subscription, $dr, $available) =
      (__('None'), __('None'), __('Disabled'), __('None'));

    my ($confBackup, $dataBackup, $domains, $size, $eta) =
      ( __('None'), __('None'), __('None'), __('Unknown'), __('Unknown') );

    if ( $rs->eBoxSubscribed() ) {
        $serverName = $rs->eBoxCommonName();

        $subscription = $rs->i18nServerEdition();

        $dr = __('Configuration backup enabled');

        # I guess 45min is enough to install Zentyal
        my $instTime = 45 * 60;

        my $drEnabled = 0;
        try {
            $drEnabled = $rs->disasterRecoveryAddOn();
        } catch EBox::Exceptions::NotConnected with { };

        if ( $drEnabled ) {
            $dr = __('Full Disaster Recovery enabled');

            my $gl = EBox::Global->getInstance();
            if ( $gl->modExists('ebackup') ) {
                my $ebackupMod = $gl->modInstance('ebackup');

                $dataBackup = $ebackupMod->lastBackupDate();
                unless ( defined($dataBackup) ) {
                    $dataBackup = __('No data backup has been done yet');
                }

                # Get the available space
                my $storageUsage = $ebackupMod->storageUsage();
                if ( defined($storageUsage) and ($storageUsage->{total} > 0) ) {
                    $available = __x('{num} GB, left: {per}',
                                     num => $self->_format($storageUsage->{available} / 1024),
                                     per => $self->_format($storageUsage->{available} / $storageUsage->{total} * 100) . ' %');
                } else {
                    $available = __('Unknown');
                }

                # Get the domains
                my $availDomains = $ebackupMod->availableBackupDomains();
                my @enabledDomains =
                  grep { $availDomains->{$_}->{enabled} } keys %{$availDomains};
                my @printableDomains =
                  map { $availDomains->{$_}->{printableName} } @enabledDomains;

                $domains = join(', ', @printableDomains);

                # Calculated the ETA
                my $global = EBox::Global->getInstance();
                if ( $global->modExists('cloud-prof') ) {
                    my $cloudProf = $global->modInstance('cloud-prof');
                    my $date = Date::Calc->gmtime();
                    foreach my $try (1 .. 5) {
                        my ($year, $month, $day) = $date->date();
                        my $downAvg = $cloudProf->averageBWDay("$year-$month-$day");
                        if ( defined($downAvg) ) {
                            $size = $self->_estimatedBackupSize($ebackupMod);
                            if ( defined($size) ) {
                                my $downTime = $size / $downAvg;
                                $eta = __x('{time} hours - Full Disaster Recovery',
                                           time => $self->_format(($downTime + $instTime)/3600, 2));
                                $size = __x('{size} MB',
                                            size => $self->_format($size / (1 << 20), 3));
                            } else {
                                $size = __('No backup done yet');
                            }
                            last;
                        } else {
                            $date = $date + [0,0,-1]; # Minus one day
                        }
                    }
                }

            } else {
                # It has DR but the ebackup mod is not installed
                $available = __('Unknown');
                $dataBackup = __x('Install {mod} module to start using '
                                  . 'Disaster Recovery', mod => 'ebackup');
            }
        } else {
            # Basic suscriptor
            $eta = __x('{time} minutes - Configuration Backup Only',
                       time => $self->_format($instTime / 60, 2));
        }

        # Get the conf backup information
        $confBackup = $rs->latestRemoteConfBackup();
        if ($confBackup eq 'unknown') {
            $confBackup = __('No configuration backup has been done yet');
        }

    }

    return {
        server_name => $serverName,
        edition     => $subscription,
        dr          => $dr,
        available   => $available,
        conf_backup => $confBackup,
        data_backup => $dataBackup,
        domains     => $domains,
        size        => $size,
        eta         => $eta,
       };
}

# Group: Private methods

sub _CBmessage
{
    return __sx('Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch} to ensure the availability of your business critical data at all times! Or start with the {ohf}free registration{ch} that lets you to store one remote configuration backup.',
                ch => '</a>',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">',
                ohf => '<a href="' . SUBS_WIZARD_URL  . '">');
}

sub _DRmessage
{
    return __sx('Want to ensure that your business critical data and system configuration is stored in a safe remote location and can be easily restored in case of a disaster? Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch}!',
                ch => '</a>',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">');
}

# Estimate the backup size using volume number
sub _estimatedBackupSize
{
    my ($self, $ebackupMod) = @_;

    my $size = 0;
    my $status = $ebackupMod->remoteStatus();
    if ( defined($status) and (scalar(@{$status}) > 0) ) {
        my $volSize = $self->_volSize();
        my $idx = scalar(@{$status});
        do {
            $idx--;
            my $backStatus = $status->[$idx];
            $size += ($backStatus->{volumes} * $volSize);
        } until ( ($status->[$idx]->{type} eq 'Full') or ($idx < 0) );
    }

    return undef unless $size > 0;
    return $size;
}

sub _volSize
{
    my $volSize = EBox::Config::configkeyFromFile('volume_size',
                                                  EBACKUP_CONF_FILE);
    if (not $volSize) {
        $volSize = 25;
    }
    return $volSize * 1024 * 1024;
}

# Format beautifully
sub _format
{
    my ($self, $num, $decNum) = @_;

    $decNum = 3 unless defined($decNum);

    my $numStr = sprintf( "%.${decNum}f", $num);
    # Remove trailing zeroes if there are any
    $numStr =~ s:0+$::;
    $numStr =~ s:\.$::;

    return $numStr;
}


1;

