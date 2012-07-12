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

package EBox::OpenVPN::Server;

# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

use base qw(EBox::OpenVPN::Daemon);

use EBox::Global;
use EBox::CA;
use EBox::FileSystem;
use EBox::Gettext;
use EBox::NetWrappers;
use EBox::NetWrappers;
use EBox::OpenVPN::Server::ClientBundleGenerator::Linux;
use EBox::OpenVPN::Server::ClientBundleGenerator::Windows;
use EBox::Validate
  qw(checkPort checkAbsoluteFilePath checkIP checkNetmask checkIPNetmask);

use List::Util qw(first);
use Params::Validate qw(validate_pos validate SCALAR ARRAYREF);
use Perl6::Junction qw(any);
use Error qw(:try);

sub new
{
    my ($class, $row) = @_;

    my $self = $class->SUPER::new($row);
    bless $self, $class;

    return $self;
}

#
# Method: daemonFiles
#
#    Get a list with the files and directories generated by the given
#    daemon. Paths must be absolute. Directories contents are not included
#
#    This is a default implementation, specifics daemon classes may want to
#    override this to include their additional files
#
#  Parameters:
#        $name - daemon name
#
# Returns:
#  a list with each path as string
sub daemonFiles
{
    my ($class, $name) = @_;

    my @files = $class->SUPER::daemonFiles($name);
    my $confDir = $class->_openvpnModule->confDir();

    my $ippFile = $class->_ippFileForDaemon($confDir, $name);
    if (-f $ippFile) {
        push @files, $ippFile;
    }

    my $serverConfigDir = $class->serverConfigDirByName($confDir, $name);
    if (-d $serverConfigDir) {
        push @files, $serverConfigDir;
    }

    return @files;
}

sub type
{
    return 'server';
}

# Method: proto
#
#  Returns:
#    the protocol used by the server
#
sub proto
{
    my ($self) = @_;

    my $config =
      $self->{row}->elementByName('configuration')->foreignModelInstance;

    my $portAndProtocol =  $config->portAndProtocolType();
    return $portAndProtocol->protocol();
}

# XXX move to toher class
sub _checkPortIsAvailable
{
    my ($self, $proto, $port, $localIface) = @_;
    validate_pos(@_, 1, 1, 1, 1);

    # we must check we haven't already set the same port to avoid usesPort
    # false positive
    my $oldPort  = $self->port();
    my $oldProto = $self->proto;
    if ( defined $oldPort and defined $oldProto) {
        if (($port == $oldPort) and ($proto eq $oldProto)  ) {
            if (defined $localIface) {
                my $currentLocalIface = $self->local();
                if (not defined $currentLocalIface) {
                    return 1;
                }elsif ($currentLocalIface eq $localIface) {
                    return 1;
                }
            }else {
                return 1;
            }
        }
    }

    my $fw = EBox::Global->modInstance('firewall');
    my $availablePort =   $fw->availablePort($proto, $port, $localIface);
    if (not $availablePort) {
        throw EBox::Exceptions::External(
                                     __x(
                                         "The port {p}/{pro} is already in use",
                                         p => $port,
                                         pro => $proto,
                                     )
        );
    }
}

# Method: port
#
#  Returns:
#   the port used by the server to receive connections.
sub port
{
    my ($self) = @_;
    my $config =
      $self->{row}->elementByName('configuration')->foreignModelInstance;

    my $portAndProtocol =  $config->portAndProtocolType();
    return $portAndProtocol->port();
}

# Method: internal
#
#   tell wether the client must been internal for users in the UI or nodaemon
#   is a internal daemon used and created by other EBox services.
#   In this point there aren;t internal server so this method always return false
#
# Returns:
#  returns the client's internal state
sub internal
{
    my ($self) = @_;
    return 0;
}

# Method: local
#
#  Gets the local network interface where the server will listen
#
#   Returns:
#      undef if the server listens in all interfaces or
#        the interface name where it listens
sub local
{
    my ($self) = @_;
    my $iface = $self->_configAttr('local');

    # redis does not store undef values, with a undef key it returns ''
    if ($iface eq  '_ALL') {
        $iface = undef;
    } else {
        my $network = EBox::Global->modInstance('network');
        $iface = $network->realIface($iface);
    }

    return $iface;
}

# Method: caCertificatePath
#
#   Returns:
#      the path to the CA's certificate
sub caCertificatePath
{
    my ($self) = @_;

    my $global = EBox::Global->instance();
    my $ca = $global->modInstance('ca');

    my $caCertificate = $ca->getCACertificateMetadata;
    defined $caCertificate
      or throw EBox::Exceptions::Internal('No CA certificate');

    return $caCertificate->{path};
}

# Method: certificate
#
#  Gets the certificate used by the server to identify itself
#
#   returns:
#      the common name of the certificate
sub certificate
{
    my ($self) = @_;
    my $cn = $self->_configAttr('certificate');
    return $cn;
}

sub checkCertificate
{
    my ($class, $cn) = @_;

    my $ca = EBox::Global->modInstance('ca');
    my $cert_r = $ca->getCertificateMetadata(cn => $cn);

    if (not defined $cert_r) {
        throw EBox::Exceptions::External(
                         __x('The certificate {cn} does not exist', cn => $cn));
    }elsif ($cert_r->{state} eq 'E') {
        throw EBox::Exceptions::External(
                            __x('The certificate {cn} has expired', cn => $cn));
    }elsif ($cert_r->{state} eq 'R') {
        throw EBox::Exceptions::External(
                       __x('The certificate {cn} has been revoked', cn => $cn));
    }

    return $cert_r;
}

# Method: certificatePath
#
# Returns:
#  the path to the certificate file
sub certificatePath
{
    my ($self) = @_;

    my $cn = $self->certificate();
    ($cn)
      or throw EBox::Exceptions::External(
                     __x(
                         'The server {name} does not have certificate assigned',
                         name => $self->name
                     )
      );

    my $certificate_r = $self->checkCertificate($cn);
    return $certificate_r->{path};
}

# Method: key
#
# Returns:
#  the path to the private key for the server's certificate
sub key
{
    my ($self) = @_;

    my $certificateCN = $self->certificate();
    ($certificateCN)
      or throw EBox::Exceptions::External(
        __x(
'Cannot get key of server {name} because it does not have any certificate assigned',
            name => $self->name
        )
      );

    $self->checkCertificate($certificateCN);

    my $ca = EBox::Global->modInstance('ca');
    my $keys = $ca->getKeys($certificateCN);

    return $keys->{privateKey};
}

# Method: crlVerify
#
#   returns the value needed for the crlVerify openvpn's option
#
# Returns:
#  the path to the current certificates revoked list
sub crlVerify
{
    my ($self) = @_;

    my $ca = EBox::Global->modInstance('ca');
    return $ca->getCurrentCRL();
}

# Method: subnet
#
# Returns:
#  the address of the VPN provided by the server
sub subnet
{
    my ($self) = @_;
    my $conf = $self->{row}->subModel('configuration');
    my $net  = $conf->vpnType();
    return $net->ip();
}

# Method: subnetNetmask
#
# Returns:
#  the netmask of the VPN provided by the server
sub subnetNetmask
{
    my ($self) = @_;
    my $conf = $self->{row}->subModel('configuration');
    my $net  = $conf->vpnType();
    my $mask = EBox::NetWrappers::mask_from_bits($net->mask);

    return $mask;
}

# Method: clientToClient
#
# Returns:
#  whether connection is allowed between clients though the VPN or not
sub clientToClient
{
    my ($self) = @_;
    return $self->_configAttr('clientToClient');
}

# Method: tlsRemote
#
# Returns:
#  value of the openvpn's tlsRemote option
sub tlsRemote
{
    my ($self) = @_;
    my $tlsRemote = $self->_configAttr('tlsRemote');
    return $tlsRemote ? $tlsRemote : undef;
}



# Method: pullRoutes
#
# Returns:
#
#    Boolean - whether the server may pull routes from client or not
#
sub pullRoutes
{
    my ($self) = @_;
    return $self->_configAttr('pullRoutes');
}

sub ripDaemon
{
    my ($self) = @_;

    $self->isEnabled()
      or return undef;

    $self->pullRoutes()
      or return undef;

    my $iface = $self->ifaceWithRipPasswd();
    return { iface => $iface };
}

sub confFileTemplate
{
    my ($self) = @_;
    return "openvpn/openvpn.conf.mas";
}

sub _ippFileForDaemon
{
    my ($class, $confDir, $name) = @_;
    my $daemonDir = $class->serverConfigDirByName($confDir, $name);
    return "$daemonDir/$name-ipp.txt";
}

# Method: ippFile
#
#  Parameters:
#   confDir (named) - configuration dir for the server
#
#  returns the ipp file path
sub ippFile
{
    my ($self, $confDir) = @_;
    return __PACKAGE__->_ippFileForDaemon($confDir, $self->name());
}


sub confFileParams
{
    my ($self, %params) = @_;
    my $confDir = $params{confDir};
    defined $confDir or
        throw EBox::Exceptions::MissingArgument('confDir');

    my @templateParams;

    push @templateParams, (dev => $self->iface());

    my @paramsNeeded =
      qw(name subnet subnetNetmask  port caCertificatePath certificatePath key crlVerify
         clientToClient user group proto dh tlsRemote
         clientConfigDir
         searchDomain dns1 dns2 wins
       );
    foreach  my $param (@paramsNeeded) {
        my $accessor_r = $self->can($param);
        my $value;
        if ($accessor_r) {
            $value = $accessor_r->($self);
        } else {
            $value = $self->_configAttr($param);
        }
        defined $value or next;
        push @templateParams, ($param => $value);
    }


    push @templateParams, (ippFile => $self->ippFile($confDir));

    # local parameter needs special mapping from iface -> ip
    push @templateParams, $self->_confFileLocalParam();

    my @advertisedNets =  $self->advertisedNets();
    push @templateParams, ( advertisedNets => \@advertisedNets);

    return \@templateParams;
}

# Method: localAddress
#
# Returns:
#  the ip address where the server will listen or undef if it
# listens in all network interfaces
sub localAddress
{
    my ($self) = @_;

    my $localAddress;
    my $localIface = $self->local();
    if ($localIface) {

        # translate local iface to a local ip
        my $network = EBox::Global->modInstance('network');
        $localIface = $network->etherIface($localIface);
        my $ifaceAddresses_r = $network->ifaceAddresses($localIface);
        my @addresses = @{$ifaceAddresses_r};
        if (@addresses == 0) {
            throw EBox::Exceptions::External(__x(
                "VPN server {name} couldn't be configured, " .
                'no IP address found for interface {iface}',
                name => $self->name,
                iface => $localIface
            ));
        }

        my $selectedAddress =  shift @addresses
          ; # XXX may be we have to look up a better address resolution method
        $localAddress = $selectedAddress->{address};
    }else {
        $localAddress = undef;
    }
}

sub _confFileLocalParam
{
    my ($self) = @_;

    my $localParamValue = $self->localAddress();
    return (local => $localParamValue);
}

sub isEnabled
{
    my ($self) = @_;
    return $self->_rowAttr('service');
}

sub masquerade
{
    my ($self) = @_;
    return $self->_configAttr('masquerade');
}

sub runningOnInternalIface
{
    my ($self) = @_;

    my $local = $self->local();

    if ($local) {
        my $network = EBox::Global->modInstance('network');
        return not $network->ifaceIsExternal($local);
    }else {

        # server listen in all ifaces
        return $self->_allIfacesAreInternal();
    }

}

sub _allIfacesAreInternal
{
    my ($self) = @_;

    my $network = EBox::Global->modInstance('network');

    my @ifaces =
      grep {$network->ifaceMethod($_) ne 'notset';} @{ $network->ifaces() };

    foreach my $iface (@ifaces) {
        return 0 if $network->ifaceIsExternal($iface);
    }

    return 1;
}

# Method: advertisedNets
#
#  gets the nets which will be advertised to client as reachable thought the server
#
# Returns:
#  a list of references to a lists containing the net address and netmask pair
sub advertisedNets
{
    my ($self) = @_;

    my @nets;

    my $global  = EBox::Global->getInstance();
    my $objMod = $global->modInstance('objects');
    my $serverConfModel = $self->{row}->subModel('configuration');
    my $vpn = $serverConfModel->row()->elementByName('vpn')->printableValue();
    my $advertisedNetsModel = $self->{row}->subModel('advertisedNetworks');
    for my $rowID (@{$advertisedNetsModel->ids()}) {
        my $row = $advertisedNetsModel->row($rowID);
        my $objId = $row->valueByName('object');
        my $mbs   = $objMod->objectMembers($objId);

        foreach my $member (@{$mbs}) {
            # use only IP address member type
            if ($member->{type} ne 'ipaddr') {
                next;
            }

            my $network = EBox::NetWrappers::to_network_with_mask(
                $member->{ip},
                EBox::NetWrappers::mask_from_bits($member->{mask})
            );

            # Advertised network address == VPN network address
            if ($network eq $vpn) {
                next;
            }

            # Add the member to the list of advertised networks
            push(@nets,[$member->{ip},
                        EBox::NetWrappers::mask_from_bits($member->{mask})]
            );
        }
    }

    return @nets;
}



sub createDirectories
{
    my ($self) = @_;

    my $path = $self->clientConfigDir();
    if (-d $path) {
        return;
    }
    EBox::Sudo::root("mkdir -p $path");
    EBox::Sudo::root("chmod -R 755 $path");
}

# return the clientConfigDir path and creates the directory if it does not exists
sub clientConfigDir
{
    my ($self) = @_;
    my $vpnDir = $self->_openvpnModule->confDir();
    my $path = $self->serverConfigDirByName($vpnDir, $self->name()) . '/client-config.d';
    return $path;
}

sub serverConfigDirByName
{
    my ($self, $vpnDir, $name) = @_;
    return $vpnDir . '/' . "$name.d";
}

# Method: setInternal
#
#
# This method is overriden here beacuse servers cannot be internal;
#  so trying to set them as internals we raise error
#
# Parameters:
#    internal - bool.
sub setInternal
{
    my ($self, $internal) = @_;

    if ($internal) {
        throw EBox::Exceptions::External(
                    __('OpenVPN servers cannot be used for internal services'));
    }

    $self->SUPER::setInternal($internal);
}

sub clientBundle
{
    my ($self, @p) = @_;
    validate(
             @p,
             {
               clientType        => { default => 'windows' },
               clientCertificate => 1,
               addresses         => { type => ARRAYREF },
               installer         => 0,
               connStrategy      => { default => 'random' },
             }
    );

    my %params = @p;

    my $clientType = delete $params{clientType};
    if ($clientType eq 'mac') {
        $clientType = 'linux';
    }
    if ( !($clientType eq any('windows',  'linux', 'EBoxToEBox')) ) {
        throw EBox::Exceptions::External(
                      __x('Unsupported client type: {ct}', ct => $clientType) );
    }

    if (@{ $params{addresses} } == 0) {
        throw EBox::Exceptions::External(
                            'You must provide a server address for the bundle');
    }

    my $class =
      'EBox::OpenVPN::Server::ClientBundleGenerator::' . ucfirst $clientType;

    $params{server} = $self;

    return $class->clientBundle(%params);
}


sub backupFiles
{
    my ($self, $dir) = @_;

    my $name = $self->name();
    my $dst = "$dir/$name";
    EBox::FileSystem::makePrivateDir($dst);

    my $vpnDir = $self->_openvpnModule->confDir();
    my $serverConfigDir = $self->serverConfigDirByName($vpnDir, $name);
    if (EBox::FileSystem::dirIsEmpty($serverConfigDir)) {
        return;
    }

    EBox::Sudo::root("cp -af $serverConfigDir/* $dst/");
    # dont store config file
    EBox::Sudo::root("rm  $dst/$name.conf");
}

sub restoreFiles
{
    my ($self, $dir) = @_;

    my $name = $self->name();
    my $src = "$dir/" . $name;
    if (not EBox::Sudo::fileTest('-d', $src)) {
        EBox::warn('No backup directory $src for server ' . $name);
        return;
    }
    if (EBox::FileSystem::dirIsEmpty($src)) {
        EBox::warn('No files in backup directory $src for server ' . $name);
        return;
    }

    my $vpnDir = $self->_openvpnModule->confDir();
    my $serverConfigDir = $self->serverConfigDirByName($vpnDir, $name);
    # clean and make directory
    EBox::Sudo::root("rm -rf $serverConfigDir");
    $self->createDirectories();

    EBox::Sudo::root("cp -af $src/* $serverConfigDir/");
    # XXX this is bz the tar file cannot preserve ownership this should be fixed
    # in EBox::Backup
    EBox::Sudo::root("chown -R root.root $serverConfigDir/*");
}


sub certificateRevoked # (commonName, isCACert)
{
    my ($self, $commonName, $isCACert) = @_;

    return 1 if $isCACert;
    return ($commonName eq $self->certificate());
}

sub certificateExpired
{
    my ($self, $commonName, $isCACert) = @_;

    if ($isCACert or  ($commonName eq $self->certificate())) {
        EBox::info('OpenVPN server '
                 . $self->name
                 . ' is now inactive because of certificate expiration issues');
        $self->_invalidateCertificate();
    }
}

sub freeCertificate
{
    my ($self, $commonName) = @_;

    if ($commonName eq $self->certificate()) {
        EBox::info('OpenVPN server '
            . $self->name
            . ' is now inactive because server certificate expired or was revoked'
        );
        $self->_invalidateCertificate();
    }
}

sub _invalidateCertificate
{
    my ($self) = @_;

    # openvpn server cannot be activated again until it has a valid certificate
    $self->_deactivate();
}

sub _deactivate
{
    my ($self) = @_;

    $self->{row}->elementByName('service')->setValue(0);
    $self->{row}->store();

   # we stop daemon to not accept more conexions with the invalidate certificate
    $self->stop() if $self->isRunning();
}

sub usesPort
{
    my ($self, $proto, $port, $iface) = @_;

    my $ownProto = $self->proto;
    defined $ownProto
      or return undef; # uninitialized server
    if ($proto ne $ownProto) {
        return undef;
    }

    my $ownPort = $self->port;
    defined $ownPort
      or return undef; #uninitialized server
    if ($port ne $ownPort) {
        return undef;
    }

    my $ownIface = $self->local;
    if ((defined $iface) and (defined $ownIface)) {
        if ($iface ne $ownIface) {
            return undef;
        }
    }

    return 1;
}

sub ifaceMethodChanged
{
    my ($self, $iface, $oldmethod, $newmethod) = @_;

    if ($self->_onlyListenOnIface($iface)) {
        return 1 if $newmethod eq 'notset';
    }

    return undef;
}

sub staticIfaceAddressChanged
{
    my ($self) = @_;
    # shoudd do nothing
    return undef;
}

sub vifaceDelete
{
    my ($self, $iface, $viface) = @_;
    return $self->_onlyListenOnIface($viface);
}

sub freeIface
{
    my ($self, $iface) = @_;

    if ($self->_onlyListenOnIface($iface)) {
        $self->_deactivate();
        EBox::warn('OpenVPN server '
            . $self->name
            . " was deactivated because it was dependent on the interface $iface"
        );
    }
}

sub freeViface
{
    my ($self, $iface, $viface) = @_;
    $self->freeIface($viface);
}

sub changeIfaceExternalProperty # (iface, external)
{
    my ($self, $iface, $external) = @_;

    # only we can break configuration if a external passes
    # to internal and masquerade is not set

    $external and return;

    my $local = $self->local();
    if ($local) {

        # check if the change is for another iface..
        return undef if $iface ne $local;
    }else {

        # if we listen all ifaces, if at least is one that is not internal
        # masquerading will not be compulsive
        return undef if not $self->_allIfacesAreInternal(
              );
    }

    return ( $self->masquerade) ?  undef : 1;
}

sub _onlyListenOnIface
{
    my ($self, $iface) = @_;

    my $local = $self->local();
    if ($local and ($iface eq $self->local() )) {
        return 1;
    }else {

        # the server listens in all ifaces...
        my $network = EBox::Global->modInstance('network');
        my @ifaces = @{ $network->ExternalIfaces };

        # XXX it should care of internal ifaces only until we close #391
        push @ifaces, @{ $network->InternalIfaces };

        if (@ifaces == 1) {
            return 1;
        }
    }

    return undef;
}

# Method: summary
#
#  returns the contents which will be used to create a summary section
#
sub summary
{
    my ($self) = @_;

    my @summary;
    push (@summary, __x('Server {name}', name => $self->name));

    my $service = $self->isEnabled() ? __('Enabled') : __('Disabled');
    push (@summary, (__('Service'), $service));

    my $running = $self->isRunning ? __('Running') : __('Stopped');
    push (@summary,(__('Daemon status'), $running));

    my $localAddress;
    try {
        $localAddress = $self->localAddress();
        defined $localAddress or $localAddress = __('All external interfaces');
    } catch EBox::Exceptions::External with {
        $localAddress = __('Not found');
    };
    push (@summary, (__('Local address'), $localAddress));

    my $proto   = $self->proto();
    my $port    = $self->port();
    my $portAndProtocol = "$port/\U$proto";
    push (@summary,(__('Port'), $portAndProtocol));

    my $subnet  = $self->subnet . '/' . $self->subnetNetmask;
    push (@summary,(__('VPN subnet'), $subnet));

    my $iface = $self->iface();
    push (@summary, (__('VPN network interface'), $iface ));

    my $addr = $self->ifaceAddress();
    unless ($addr) { $addr = __('No active') };
    push (@summary, (__('VPN interface address'), $addr));

    return @summary;
}

1;
