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

package EBox::RemoteServices::QAUpdates;
#   Package to manage the Zentyal QA Updates

use strict;
use warnings;

use HTML::Mason;
use File::Slurp;
use File::Temp;

use EBox::Config;
use EBox::Exceptions::Command;
use EBox::Global;
use EBox::Module::Base;
use EBox::RemoteServices::Configuration;
use EBox::RemoteServices::Cred;
use EBox::Sudo;
use Data::UUID;

use Error qw(:try);

# Group: Public methods

# Method: set
#
#       Turn the QA Updates ON or OFF depending on the subscription level
#
sub set
{
    # Downgrade, if necessary
    _downgrade();

    _setQAUpdates();
}

# Group: Private methods

sub _setQAUpdates
{
    # Set the QA Updates if the subscription level is greater than basic
    my $rs = EBox::Global->modInstance('remoteservices');
    return unless ($rs->subscriptionLevel(1) > 0);

    _setQASources();
    _setQAAptPubKey();
    _setQAAptPreferences();
    _setQARepoConf();

    my $softwareMod = EBox::Global->modInstance('software');
    if ($softwareMod) {
        if ( $softwareMod->can('setQAUpdates') ) {
            $softwareMod->setQAUpdates(1);
        }
    } else {
        EBox::info('No software module installed QA updates should be done by hand');
    }
}

# Set the QA source list
sub _setQASources
{
    my $archive = _archive();
    my $repositoryHostname = _repositoryHostname();

    my $output;
    my $interp = new HTML::Mason::Interp(out_method => \$output);
    my $sourcesFile = EBox::Config::stubs . 'remoteservices/qa-sources.mas';
    my $comp = $interp->make_component(comp_file => $sourcesFile);
    my $cred = EBox::RemoteServices::Cred->new()->{cred};
    my $user = $cred->{name};
    # Password: UUID in hexadecimal format (without '0x')
    my $ug = new Data::UUID;
    my $bin_uuid = $ug->from_string($cred->{uuid});
    my $hex_uuid = $ug->to_hexstring($bin_uuid);
    my $pass = substr($hex_uuid, 2);                # Remove the '0x'

    my @tmplParams = ( (repositoryHostname  => $repositoryHostname),
                       (archive             => $archive),
                       (user                => $user),
                       (pass                => $pass));
    # Secret variables for testing
    if ( EBox::Config::configkey('qa_updates_repo_port') ) {
        push(@tmplParams, (port => EBox::Config::configkey('qa_updates_repo_port')));
    }
    if ( EBox::Config::boolean('qa_updates_repo_no_ssl') ) {
        push(@tmplParams, (ssl => (not EBox::Config::boolean('qa_updates_repo_no_ssl'))));
    }


    $interp->exec($comp, @tmplParams);

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    my $tmpFile = $fh->filename();
    File::Slurp::write_file($tmpFile, $output);
    my $destination = EBox::RemoteServices::Configuration::aptQASourcePath();
    EBox::Sudo::root("install -m 0644 '$tmpFile' '$destination'");
}

# Get the ubuntu version
sub _ubuntuVersion
{
    my @releaseInfo = File::Slurp::read_file('/etc/lsb-release');
    foreach my $line (@releaseInfo) {
        next unless ($line =~ m/^DISTRIB_CODENAME=/ );
        chomp $line;
        my ($key, $version) = split '=', $line;
        return $version;
    }
}

# Get the Zentyal version to use in the archive
sub _zentyalVersion
{
    # Comment out when stable is launched
    # return substr(EBox::Config::version(),0,3);
    return '3.0';
}

# Get the QA archive to look
sub _archive
{
    my $ubuntuVersion = _ubuntuVersion();
    my $zentyalVersion = _zentyalVersion();

    return "zentyal-qa-$zentyalVersion-$ubuntuVersion";

}

# Get the suite of archives to set preferences
sub _suite
{
    return 'zentyal-qa';
}

# Set the QA apt repository public key
sub _setQAAptPubKey
{
    my $keyFile = EBox::Config::conf() . 'remoteservices/zentyal-qa.pub';
    EBox::Sudo::root("apt-key add $keyFile");
}

sub _setQAAptPreferences
{
    my $preferences = '/etc/apt/preferences';
    my $fromCCPreferences = $preferences . '.zentyal.fromzc'; # file to store CC preferences

    my $output;
    my $interp = new HTML::Mason::Interp(out_method => \$output);
    my $prefsFile = EBox::Config::stubs . 'remoteservices/qa-preferences.mas';
    my $comp = $interp->make_component(comp_file  => $prefsFile);
    $interp->exec($comp, ( (archive => _suite()) ));

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    my $tmpFile = $fh->filename();
    File::Slurp::write_file($tmpFile, $output);

    EBox::Sudo::root("cp '$tmpFile' '$fromCCPreferences'");

    return unless EBox::Config::boolean('qa_updates_exclusive_source');

    my $preferencesDirFile = EBox::RemoteServices::Configuration::aptQAPreferencesPath();
    EBox::Sudo::root("install -m 0644 '$fromCCPreferences' '$preferencesDirFile'");
}

# Set up the APT conf
#  * No use HTTP proxy for QA repository
#  * No verify server certificate
sub _setQARepoConf
{
    my $repoHostname = _repositoryHostname();
    EBox::Module::Base::writeConfFileNoCheck(EBox::RemoteServices::Configuration::aptQAConfPath(),
                                             '/remoteservices/qa-conf.mas',
                                             [ repoHostname => $repoHostname ]);
}

# Get the repository hostname
sub _repositoryHostname
{
    my $rs = EBox::Global->modInstance('remoteservices');
    return 'qa.' . $rs->cloudDomain();
}

# Remove QA updates
sub _removeQAUpdates
{
    _removeAptQASources();
    _removeAptPubKey();
    _removeAptQAPreferences();
    _removeAptQAConf();

    my $softwareMod = EBox::Global->modInstance('software');
    if ($softwareMod) {
        if ( $softwareMod->can('setQAUpdates') ) {
            $softwareMod->setQAUpdates(0);
        }
    }
}

sub _removeAptQASources
{
    my $path = EBox::RemoteServices::Configuration::aptQASourcePath();
    EBox::Sudo::root("rm -f '$path'");
}

sub _removeAptPubKey
{
    my $id = 'ebox-qa';
    try {
        EBox::Sudo::root("apt-key del $id");
    } otherwise {
        EBox::error("Removal of apt-key $id failed. Check it and if it exists remove it manually");
    };
}

sub _removeAptQAPreferences
{
    my $path = '/etc/apt/preferences.zentyal.fromzc';
    EBox::Sudo::root("rm -f '$path'");
    $path = EBox::RemoteServices::Configuration::aptQAPreferencesPath();
    EBox::Sudo::root("rm -f '$path'");
}

sub _removeAptQAConf
{
    my $path = EBox::RemoteServices::Configuration::aptQAConfPath();
    EBox::Sudo::root("rm -f '$path'");
}

# Downgrade current subscription, if necessary
# Things to be done:
#   * Remove QA updates configuration
#   * Uninstall zentyal-cloud-prof and zentyal-security-updates packages
#
sub _downgrade
{
    my $rs = EBox::Global->modInstance('remoteservices');
    # If Basic subscription or no subscription at all
    if ($rs->subscriptionLevel(1) <= 0) {
        if ( -f EBox::RemoteServices::Configuration::aptQASourcePath()
            or -f EBox::RemoteServices::Configuration::aptQAPreferencesPath() ) {
            # Requires to downgrade
            _removeQAUpdates();
        }
    }
}

1;
