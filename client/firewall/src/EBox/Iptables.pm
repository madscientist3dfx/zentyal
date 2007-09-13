# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Iptables;
# Package to manage iptables command utility

use EBox::Firewall;
use EBox::Global;
use EBox::Gettext;
use EBox::Objects;
use EBox::Network;
use EBox::Firewall::IptablesHelper;
use EBox::Exceptions::Internal;
use Error qw( :try );
use EBox::Sudo qw( :all );

my $new = " -m state --state NEW ";

use constant CONNTRACK_MODULES => ('ip_conntrack_ftp');

# Constructor: new
#
#      Create a new EBox::Iptables object
#
# Returns:
#
#      A recently created EBox::Iptables object
sub new
{
	my $class = shift;
	my $self = {};
	$self->{firewall} = EBox::Global->modInstance('firewall');
	$self->{objects} = EBox::Global->modInstance('objects');
	$self->{net} = EBox::Global->modInstance('network');
	$self->{deny} = $self->{firewall}->denyAction;


	bless($self, $class);
	return $self;
}

# Method: pf
#
#       Execute iptables command with options
#
# Parameters:
#
#       opts - options passed to iptables
#
# Returns:
#
#       array ref - the output of iptables command in an array
#
sub pf # (options)
{
	my $opts = $_[-1];
	return root("/sbin/iptables $opts");
}

# Method: startIPForward
#
#       Change kernel to do IPv4 forwarding (default)
#
# Returns:
#
#       array ref - the output of sysctl command in an array
#
sub startIPForward
{
	root('/sbin/sysctl -q -w net.ipv4.ip_forward="1"');
}

# Method: stopIPForward
#
#       Change kernel to stop doing IPv4 forwarding
#
# Returns:
#
#       array ref - the output of sysctl command in an array
#
sub stopIPForward
{
	root('/sbin/sysctl -q -w net.ipv4.ip_forward="0"');
}

# Method: clearTables
#
#       Clear all tables (user defined and nat), set a policy to
#       OUTPUT, INPUT and FORWARD chains and allow always traffic
#       from/to loopback interface.
#
# Parameters:
#
#       policy - It can be a target
#       (ACCEPT|DROP|REJECT|QUEUE|RETURN|user-defined chain)
#       See iptables TARGETS section
#
sub clearTables # (policy)
{
	my $self = shift;
	my $policy = shift;
	pf "-F";
	pf "-X";
	pf "-t nat -F";
	pf "-t nat -X";
	# Allow loopback 
	if (($policy eq 'DROP') or ($policy eq 'REJECT')) {
		pf '-A INPUT -i lo -j ACCEPT';
		pf '-A OUTPUT -o lo -j ACCEPT';
	}
	pf "-P OUTPUT $policy";
	pf "-P INPUT $policy";
	pf "-P FORWARD $policy";
}

# Method: setStructure
#
#       Set structure to Firewall module to work
#
sub setStructure
{
	my $self = shift;
	$self->clearTables("DROP");

	# state rules
	pf '-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT';
	pf '-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT';
	pf '-A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT';

	pf '-A OUTPUT -p icmp ! -f -j ACCEPT';
	pf '-A INPUT -p icmp ! -f -j ACCEPT';
	pf '-A FORWARD -p icmp ! -f -j ACCEPT';

	pf '-t nat -N premodules';

	pf '-t nat -N postmodules';

	pf '-N fnospoof';
	pf '-N fredirects';
	pf '-N fmodules';
	pf '-N ffwdrules';
	pf '-N fnoexternal';
	pf '-N fdns';
	pf '-N fobjects';
	pf '-N fglobal';
	pf '-N fdrop';
	pf '-N ftoexternalonly';

	pf '-N inospoof';
	pf '-N inointernal';
	pf '-N iexternalmodules';
	pf '-N iexternal';
	pf '-N inoexternal';
	pf '-N imodules';
	pf '-N iintservs';
	pf '-N iglobal';
	pf '-N idrop';


	pf '-N ointernal';
	pf '-N omodules';
	pf '-N oglobal';

	pf '-t nat -A PREROUTING -j premodules';

	pf '-t nat -A POSTROUTING -j postmodules';

	pf '-A FORWARD -j fnospoof';
	pf '-A FORWARD -j fredirects';
	pf '-A FORWARD -j fmodules';
	pf '-A FORWARD -j ffwdrules';
	pf '-A FORWARD -j fnoexternal';
	pf '-A FORWARD -j fdns';
	pf '-A FORWARD -j fobjects';
	pf '-A FORWARD -j fglobal';
	pf '-A FORWARD -j fdrop';

	pf '-A INPUT -j inospoof';
	pf '-A INPUT -j iexternalmodules';
	pf '-A INPUT -j iexternal';
	pf '-A INPUT -j inoexternal';
	pf '-A INPUT -j imodules';
	pf '-A INPUT -j iintservs';
	pf '-A INPUT -j iglobal';
	pf '-A INPUT -j idrop';

	pf '-A OUTPUT -j ointernal';
	pf '-A OUTPUT -j omodules';
	pf '-A OUTPUT -j oglobal';

	pf "-A idrop -j " . $self->{deny};
	pf "-A fdrop -j " . $self->{deny};
}

# Method: setDNS
#
#       Set DNS traffic for forwarding and output with destination dns
#
# Parameters:
#
#       dns - address/[mask] destination to accept DNS traffic
#
sub setDNS # (dns)
{
	my $self = shift;
	my $dns = shift;
	pf "-A ointernal $new -p udp --dport 53 -d $dns -j ACCEPT";
	pf "-A fdns $new -p udp --dport 53 -d $dns -j ACCEPT";
}

# Method: nospoof
#
#       Set no IP spoofing (forged) for the given addresses to the
#       interface given
#
# Parameters:
#
# interface - the allowed interface for the addresses 
# addresses - An array ref with the address to allow traffic from
#             the given interface. Each slot has the following
#             fields:
#                - address - the IP address
#                - netmask - the IP network mask

sub nospoof # (interface, \@addresses)
{
	my $self = shift;
	my ($iface, $addreses) = @_;
	foreach (@{$addresses}) {
		my $addr = $_->{address};
		my $mask = $_->{netmask};
		pf "-A fnospoof -s $addr/$mask -i ! $iface -j fdrop";
		pf "-A inospoof -s $addr/$mask -i ! $iface -j idrop";
		pf "-A inospoof -i ! $iface -d $addr -j idrop";
	}
}

# Method: redirect
#
#       Redirect traffic (protocol/port) via an specific
#       interface to an address and port. In fact, do a NAT.
#
# Parameters:
#
#       protocol  - the protocol to redirect 
#       inport    - the port from traffic gets in
#       address   - the destination address
#       interface - the destination interface
#       dport     - the destination port
#       (Positional parameters)
sub redirect # (protocol, ext_port, address, interface, dest_port)
{
	my $self = shift;
	my ($proto, $inport, $address, $iface, $dport) = @_;
	my $extaddr = $self->{net}->ifaceAddress($iface);
	defined($extaddr) or return;
	$extaddr ne '' or return;

	$iface = vifaceRealname($iface);
	my $opts = "-t nat -A PREROUTING -i $iface -d $extaddr ";
	$opts .= "-p $proto --dport $inport -j DNAT --to $address:$dport";
	pf $opts;
	pf " -A fredirects $new -p $proto --dport $dport -d $address -i " .
	    $iface . " -j ACCEPT";
}

# Method: localRedirects
#
#       Do effective local redirections. Done via
#       <EBox::Firewall::addLocalRedirect> using NAT.
#
sub localRedirects
{
	my $self = shift;
	my $redirects = $self->{firewall}->localRedirects();
	foreach my $redir (@{$redirects}) {
		my $service = $redir->{service};
		my $protocol = $self->{firewall}->serviceProtocol($service);
		my $dport = $self->{firewall}->servicePort($service);
		my $eport = $redir->{port};
		my @ifaces = @{$self->{net}->InternalIfaces()};
		foreach my $ifc (@ifaces) {
			my $addr = $self->{net}->ifaceAddress($ifc);
			(defined($addr) && $addr ne "") or next;
			pf "-t nat -A PREROUTING -i $ifc -p $protocol ".
			   "-d ! $addr --dport $eport " .
			   "-j REDIRECT --to-ports $dport";
		}
	}
}

# Method: doService
#
#       Set available an specific internal service
#
# Parameters:
#
#       service - a hash containing the following elements:
#           - port     - destination port
#           - protocol - destination protocol
#           - name     - name of service
#
sub doService # (service)
{
	my ($self, $srv) = @_;
	my $port = $srv->{port};
	my $protocol = $srv->{protocol};
	my $name = $srv->{name};
	if ($self->{firewall}->serviceIsInternal($name)) {
		pf "-A iintservs -p $protocol --dport $port -j ACCEPT";
	}
}

# Method: stop
#
#       Stop iptables service, stop forwarding from kernel
#       and free all tables
#
sub stop
{
	my $self = shift;
	stopIPForward();
	$self->clearTables("ACCEPT");
}

# Method: vifaceRealname
#
#       Return the real name from a virtual interface
#
# Parameters:
#
#       viface - Virtual interface
#
# Returns:
#
#       string - The real name from the given virtual interface
#
sub vifaceRealname # (viface)
{
	my $virtual = shift;
	$virtual =~ s/:.*$//;
	return $virtual;
}

# Method: start
#
#       Start firewall service setting up the structure and the rules
#       to work with iptables.
#
sub start
{
	my $self = shift;

	$self->_loadConntrackModules();

	$self->setStructure();

	my @dns = @{$self->{net}->nameservers()};
	foreach (@dns) {
		$self->setDNS($_);
	}

	foreach my $object (@{$self->{objects}->objects}) {
		my $members = $self->{objects}->objectMembers($object);
		foreach my $member (@{$members}) {
			my $mac = $member->{macaddr};
			defined($mac) or next;
			($mac ne "") or next;
			my $address = $member->{ipaddr};
			pf "-A inospoof -m mac -s $address " .
			   "--mac-source ! $mac -j idrop";
			pf "-A fnospoof -m mac -s $address " .
			   "--mac-source ! $mac -j fdrop";
		}
	}

	my @ifaces = @{$self->{net}->ifaces()};
	foreach my $ifc (@ifaces) {
		my $addrs = $self->{net}->ifaceAddresses($ifc);
		$self->nospoof($ifc, $addrs);
		if ($self->{net}->ifaceMethod($ifc) eq 'dhcp') {
			my $dnsSrvs = $self->{net}->DHCPNameservers($ifc);
			foreach my $srv (@{$dnsSrvs}) {
				$self->setDNS($srv);
			}
		}
	}

	my $redirects = $self->{firewall}->portRedirections;
	foreach (@{$redirects}) {
		$self->redirect($_->{'protocol'},
				$_->{'eport'},
				$_->{'ip'},
				$_->{'iface'},
				$_->{'dport'});
	}

	@ifaces = @{$self->{net}->ExternalIfaces()};
	foreach my $if (@ifaces) {
		pf "-A fnoexternal $new -i $if -j fdrop";
		pf "-A inoexternal $new -i $if -j idrop";
		pf "-A ftoexternalonly -o $if -j ACCEPT";

		if ($self->{net}->ifaceMethod($if) eq 'static') {
			my $addr = $self->{net}->ifaceAddress($if);
			pf "-t nat -A POSTROUTING -s ! $addr -o $if " .
			   "-j SNAT --to $addr"
		} elsif ($self->{net}->ifaceMethod($if) eq 'dhcp') {
			pf "-t nat -A POSTROUTING -o $if -j MASQUERADE";
		}
	}

	$self->_iexternal();
	$self->_iglobal();


	pf "-A ftoexternalonly -j fdrop";

	my $rules = $self->{firewall}->OutputRules();
	foreach my $rule (@{$rules}) {
		defined($rule) or next;
		my $port = $rule->{port};
		my $proto = $rule->{protocol};
		pf "-A ointernal $new  -p $proto --dport $port -j ACCEPT";
	}

	$self->_fglobal();
	
	$self->_ffwdrules();

	$self->_oglobal();

	$self->localRedirects();

	startIPForward();


	my $global = EBox::Global->getInstance();
	my @modNames = @{$global->modNames}; 
	my @mods = @{$global->modInstancesOfType('EBox::FirewallObserver')};
	foreach my $mod (@mods) {
		my $helper = $mod->firewallHelper();
		($helper) or next;
		$self->_doRuleset('nat', 'premodules', $helper->prerouting);
		$self->_doRuleset('nat', 'postmodules', $helper->postrouting);
		$self->_doRuleset('filter', 'fmodules', $helper->forward);
		$self->_doRuleset('filter', 'iexternalmodules', $helper->externalInput);
		$self->_doRuleset('filter', 'imodules', $helper->input);
		$self->_doRuleset('filter', 'omodules', $helper->output);
	}
}

sub _loadConntrackModules 
{
	foreach my $module (CONNTRACK_MODULES) {
		try {
			root("modprobe $module");
		} catch EBox::Exceptions::Internal with {};
	}
}

sub _doRuleset # (table, chain, \@rules)
{
	my ($self, $table, $chain, $rules) = @_;

	foreach my $rule (@{$rules}) {
		pf "-t $table -A $chain $rule";
	}
}

# Method: _iexternalCheckInit
#
# 	Add checks to iexternalmodules and iexternal to only affect
# 	packates coming from external interfaces
sub _iexternalCheckInit
{
    my ($self) = @_;

    my @internalIfaces = @{$self->{net}->InternalIfaces()};
    foreach my $if (@internalIfaces) {
        pf "-A inointernal -i $if -j RETURN";
    }

    pf "-I iexternalmodules -j inointernal";
    pf "-I iexternal -j inointernal";


}

# Method: _iexternal
#
# 	Add checks to iexternalmodules and iexternal to only affect
# 	packates coming from external interfaces
sub _iexternal
{
    my ($self) = @_;

    $self->_iexternalCheckInit();
    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->ExternalToEBoxRuleTable()}) {
        pf "$rule";
    }
    
}

# Method: _iglobal
#
#	Add rules to iglobal, that is the chain to control access
#	from the internal networks to eBox
sub _iglobal
{
    my ($self) = @_;

    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->InternalToEBoxRuleTable()}) {
        pf "$rule";
    }
    
}

# Method: _oglobal
#
#	Add rules to iglobal, that is the chain to control access
#	from eBox to external services
sub _oglobal
{
    my ($self) = @_;

    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->EBoxOutputRuleTable()}) {
        pf "$rule";
    }
    
}


# Method: _fglobal
#
#	Add rules to fglobal, that is the chain to control access
#	from the internal networks to Internet
sub _fglobal
{
    my ($self) = @_;

    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->ToInternetRuleTable()}) {
        pf "$rule";
    }
    
}

# Method: _ffwdrules
#
#	Add rules to ffwdrules, that is the chain to control access
#	from the external networks to Internet
sub _ffwdrules
{
    my ($self) = @_;

    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->ExternalToInternalRuleTable()}) {
        pf "$rule";
    }
    
}
1;
