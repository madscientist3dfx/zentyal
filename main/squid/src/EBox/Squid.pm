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

package EBox::Squid;

use strict;
use warnings;

use base qw(EBox::Module::Service EBox::KerberosModule
            EBox::FirewallObserver EBox::LogObserver EBox::LdapModule
            EBox::Report::DiskUsageProvider EBox::NetworkObserver);

use EBox::Service;
use EBox::Objects;
use EBox::Global;
use EBox::Config;
use EBox::Firewall;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;

use EBox::SquidFirewall;
use EBox::Squid::LogHelper;
use EBox::Squid::LdapUserImplementation;

use EBox::DBEngineFactory;
use EBox::Dashboard::Value;
use EBox::Dashboard::Section;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo;
use EBox::Gettext;
use EBox;
use Error qw(:try);
use HTML::Mason;
use File::Basename;

use EBox::NetWrappers qw(to_network_with_mask);

#Module local conf stuff
use constant DGDIR => '/etc/dansguardian';
use constant {
    SQUIDCONFFILE => '/etc/squid3/squid.conf',
    SQUIDCSSFILE => '/etc/squid3/errorpage.css',
    MAXDOMAINSIZ => 255,
    SQUIDPORT => '3128',
    DGPORT => '3129',
    DGLISTSDIR => DGDIR . '/lists',
    DG_LOGROTATE_CONF => '/etc/logrotate.d/dansguardian',
    SQUID_LOGROTATE_CONF => '/etc/logrotate.d/squid3',
    CLAMD_SCANNER_CONF_FILE => DGDIR . '/contentscanners/clamdscan.conf',
    BLOCK_ADS_PROGRAM => '/usr/bin/adzapper.wrapper',
    BLOCK_ADS_EXEC_FILE => '/usr/bin/adzapper',
    ADZAPPER_CONF => '/etc/adzapper.conf',
    KEYTAB_FILE => '/etc/squid3/HTTP.keytab',
    SQUID3_DEFAULT_FILE => '/etc/default/squid3',
    CRONFILE => '/etc/cron.d/zentyal-squid',
};

use constant SB_URL => 'https://store.zentyal.com/small-business-edition.html/?utm_source=zentyal&utm_medium=proxy&utm_campaign=smallbusiness_edition';
use constant ENT_URL => 'https://store.zentyal.com/enterprise-edition.html/?utm_source=zentyal&utm_medium=proxy&utm_campaign=enterprise_edition';

sub _create
{
    my $class = shift;
    my $self  = $class->SUPER::_create(name => 'squid',
                                       printableName => __('HTTP Proxy'),
                                       @_);
    $self->{logger} = EBox::logger();
    bless ($self, $class);
    return $self;
}

sub kerberosServicePrincipals
{
    my ($self) = @_;

    my $data = { service    => 'proxy',
                 principals => [ 'HTTP' ],
                 keytab     => KEYTAB_FILE,
                 keytabUser => 'proxy' };
    return $data;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    $self->SUPER::initialSetup($version);

    # Create default rules only if installing the first time
    unless ($version) {
        # Allow clients to browse Internet by default
        $self->model('AccessRules')->add(
            source => { any => undef },
            policy => { allow => undef },
        );
    }
}

# Method: enableActions
#
#   Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    # Create the kerberos service princiapl in kerberos,
    # export the keytab and set the permissions
    $self->kerberosCreatePrincipals();

    try {
        # FIXME: this should probably be moved to _setConf
        # only if users is enabled and needed
        my @lines = ();
        push (@lines, 'KRB5_KTNAME=' . KEYTAB_FILE);
        push (@lines, 'export KRB5_KTNAME');
        my $lines = join ('\n', @lines);
        my $cmd = "echo '$lines' >> " . SQUID3_DEFAULT_FILE;
        EBox::Sudo::root($cmd);
    } otherwise {
        my $error = shift;
        EBox::error("Error creating squid default file: $error");
    };

    # Execute enable-module script
    $self->SUPER::enableActions();
}

sub isRunning
{
    return EBox::Service::running('squid3');
}

# Method: usedFiles
#
#       Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [
            {
             'file' => '/etc/squid3/squid.conf',
             'module' => 'squid',
             'reason' => __('HTTP Proxy configuration file')
            },
            {
             'file' => DGDIR . '/dansguardian.conf',
             'module' => 'squid',
             'reason' => __('Content filter configuration file')
            },
            {
             'file' => DGDIR . '/dansguardianf1.conf',
             'module' => 'squid',
             'reason' => __('Default filter group configuration')
            },
            {
             'file' => DGLISTSDIR . '/filtergroupslist',
             'module' => 'squid',
             'reason' => __('Filter groups membership')
            },
            {
             'file' => DGLISTSDIR . '/bannedextensionlist',
             'module' => 'squid',
             'reason' => __('Content filter banned extension list')
            },
            {
             'file' => DGLISTSDIR . '/bannedmimetypelist',
             'module' => 'squid',
             'reason' => __('Content filter banned mime type list')
            },
            {
             'file' => DGLISTSDIR . '/exceptionsitelist',
             'module' => 'squid',
             'reason' => __('Content filter exception site list')
            },
            {
             'file' => DGLISTSDIR . '/greysitelist',
             'module' => 'squid',
             'reason' => __('Content filter grey site list')
            },
            {
             'file' => DGLISTSDIR . '/bannedsitelist',
             'module' => 'squid',
             'reason' => __('Content filter banned site list')
            },
            {
             'file' => DGLISTSDIR . '/exceptionurllist',
             'module' => 'squid',
             'reason' => __('Content filter exception URL list')
            },
            {
             'file' => DGLISTSDIR . '/greyurllist',
             'module' => 'squid',
             'reason' => __('Content filter grey URL list')
            },
            {
             'file' => DGLISTSDIR . '/bannedurllist',
             'module' => 'squid',
             'reason' => __('Content filter banned URL list')
            },
            {
             'file' =>    DGLISTSDIR . '/bannedphraselist',
             'module' => 'squid',
             'reason' => __('Forbidden phrases list'),
            },
            {
             'file' =>    DGLISTSDIR . '/exceptionphraselist',
             'module' => 'squid',
             'reason' => __('Exception phrases list'),
            },
            {
             'file' =>    DGLISTSDIR . '/pics',
             'module' => 'squid',
             'reason' => __('PICS ratings configuration'),
            },
            {
             'file' => DG_LOGROTATE_CONF,
             'module' => 'squid',
             'reason' => __(q{Dansguardian's log rotation configuration}),
            },
            {
             'file' => CLAMD_SCANNER_CONF_FILE,
             'module' => 'squid',
             'reason' => __(q{Dansguardian's antivirus scanner configuration}),
            },
            {
             'file' =>    DGLISTSDIR . '/authplugins/ipgroups',
             'module' => 'squid',
             'reason' => __('Filter groups per IP'),
            },
            {
             'file' =>    ADZAPPER_CONF,
             'module' => 'squid',
             'reason' => __('Configuration of adzapper'),
            },
            {
             'file' => SQUID3_DEFAULT_FILE,
             'module' => 'squid',
             'reason' => __('Set the kerberos keytab path'),
            },
            {
             'file' => KEYTAB_FILE,
             'module' => 'squid',
             'reason' => __('Extract the service principal key'),
            }
    ];
}


# Method: actions
#
#       Override EBox::Module::Service::actions
#
sub actions
{
    return [
            {
             'action' => __('Overwrite blocked page templates'),
             'reason' => __('Dansguardian blocked page templates will be overwritten with Zentyal'
                           . ' customized templates.'),
             'module' => 'squid'
            },
            {
             'action' => __('Remove dansguardian init script link'),
             'reason' => __('Zentyal will take care of starting and stopping ' .
                        'the services.'),
             'module' => 'squid'
            }
           ];
}

sub _cache_mem
{
    my $cache_mem = EBox::Config::configkey('cache_mem');
    ($cache_mem) or
        throw EBox::Exceptions::External(__('You must set the '.
                        'cache_mem variable in the Zentyal configuration file'));
    return $cache_mem;
}

sub _max_object_size
{
    my $max_object_size = EBox::Config::configkey('maximum_object_size');
    ($max_object_size) or
        throw EBox::Exceptions::External(__('You must set the '.
                        'max_object_size variable in the Zentyal configuration file'));
    return $max_object_size;
}

# Method: transproxy
#
#       Returns if the transparent proxy mode is enabled
#
# Returns:
#
#       boolean - true if enabled, otherwise undef
#
sub transproxy
{
    my ($self) = @_;

    return $self->model('GeneralSettings')->value('transparentProxy');
}

# Method: https
#
#       Returns if the https mode is enabled
#
# Returns:
#
#       boolean - true if enabled, otherwise undef
#
sub https
{
    my ($self) = @_;

    return $self->model('GeneralSettings')->value('https');
}

# Method: setPort
#
#       Sets the listening port for the proxy
#
# Parameters:
#
#       port - string: port number
#
sub setPort
{
    my ($self, $port) = @_;

    $self->model('GeneralSettings')->setValue('port', $port);
}


# Method: port
#
#       Returns the listening port for the proxy
#
# Returns:
#
#       string - port number
#
sub port
{
    my ($self) = @_;

    my $port = $self->model('GeneralSettings')->value('port');

    unless (defined($port) and ($port =~ /^\d+$/)) {
        return SQUIDPORT;
    }

    return $port;
}

# Function: banThreshold
#
#       Gets the weighted phrase value that will cause a page to be banned.
#
# Returns:
#
#       A positive integer with the current ban threshold.
#
sub banThreshold
{
    my ($self) = @_;
    my $model = $self->model('ContentFilterThreshold');
    return $model->contentFilterThresholdValue();
}

# Method: getAdBlockPostMatch
#
#     Get the file with the ad-blocking post match
#
# Returns:
#
#     String - the ad-block file path postmatch
#
sub getAdBlockPostMatch
{
    my ($self) = @_;

    my $adBlockPostMatch = $self->get_string('ad_block_post_match');
    defined $adBlockPostMatch or
        $adBlockPostMatch = '';
    return $adBlockPostMatch;
}

# Method: setAdBlockPostMatch
#
#     Set the file with the ad-blocking post match
#
# Parameters:
#
#     file - String the ad-block file path postmatch
#
sub setAdBlockPostMatch
{
    my ($self, $file) = @_;

    $self->set_string('ad_block_post_match', $file);
}

# Method: setAdBlockExecFile
#
#     Set the adblocker exec file
#
# Parameters:
#
#     file - String the ad-block exec file
#
sub setAdBlockExecFile
{
    my ($self, $file) = @_;

    if ($file) {
        EBox::Sudo::root("cp -f $file " . BLOCK_ADS_EXEC_FILE);
    }
}

sub filterNeeded
{
    my ($self) = @_;

    unless ($self->isEnabled()) {
        return 0;
    }

    my $rules = $self->model('AccessRules');
    if ($rules->rulesUseFilter()) {
        return 1;
    }

    return 0;
}

sub authNeeded
{
    my ($self) = @_;

    unless ($self->isEnabled()) {
        return 0;
    }

    my $rules = $self->model('AccessRules');
    return $rules->rulesUseAuth();
}

# Function: usesPort
#
#       Implements EBox::FirewallObserver interface
#
sub usesPort
{
    my ($self, $protocol, $port, $iface) = @_;

    ($protocol eq 'tcp') or return undef;
    # DGPORT is hard-coded, it is reported as used even if
    # the service is disabled.
    ($port eq DGPORT) and return 1;
    # the port selected by the user (by default SQUIDPORT) is only reported
    # if the service is enabled
    ($self->isEnabled()) or return undef;
    ($port eq $self->port) and return 1;
    return undef;
}

sub _setConf
{
    my ($self) = @_;

    my $filter = $self->filterNeeded();

    $self->_writeSquidConf($filter);

    if ($filter) {
        $self->_writeDgConf();
    }
}

sub _antivirusNeeded
{
    my ($self, $profiles_r) = @_;

    my $global = $self->global();
    return 0 unless $global->modExists('antivirus');
    return 0 unless $global->modInstance('antivirus')->isEnabled();

    if (not $profiles_r) {
        my $profiles = $self->model('FilterProfiles');
        return $profiles->antivirusNeeded();
    }

    foreach my $profile (@{ $profiles_r }) {
        if ($profile->{antivirus}) {
            return 1;
        }
    }

    return 0;
}


sub notifyAntivirusEnabled
{
    my ($self, $enabled) = @_;
    $self->filterNeeded() or
        return;

    $self->setAsChanged();
}

sub _writeSquidConf
{
    my ($self, $filter) = @_;

    my $rules = $self->model('AccessRules')->rules();

    my $generalSettings = $self->model('GeneralSettings');
    my $cacheDirSize = $generalSettings->cacheDirSizeValue();
    my $removeAds    = $generalSettings->removeAdsValue();
    my $kerberos     = $generalSettings->kerberosValue();

    my $global  = $self->global();
    my $network = $global->modInstance('network');
    my $sysinfo = $global->modInstance('sysinfo');

    my $append_domain = $network->model('SearchDomain')->domainValue();

    my $cache_host = $network->model('Proxy')->serverValue();
    my $cache_port = $network->model('Proxy')->portValue();
    my $cache_user = $network->model('Proxy')->usernameValue();
    my $cache_passwd = $network->model('Proxy')->passwordValue();

    my $users = $global->modInstance('users');

    my $krbRealm = '';
    if ($kerberos) {
        $krbRealm = $users->kerberosRealm();
    }
    my $krbPrincipal = 'HTTP/' . $sysinfo->hostName() . '.' . $sysinfo->hostDomain();

    my $dn = $users->ldap()->dn();

    my @writeParam = ();
    push @writeParam, ('filter' => $filter);
    push @writeParam, ('port'  => $self->port());
    push @writeParam, ('transparent'  => $self->transproxy());
    push @writeParam, ('https'  => $self->https());
    push @writeParam, ('localnets' => $self->_localnets());
    push @writeParam, ('rules' => $rules);
    push @writeParam, ('objectsDelayPools' => $self->_objectsDelayPools);
    push @writeParam, ('nameservers' => $network->nameservers());
    push @writeParam, ('append_domain' => $append_domain);

    push @writeParam, ('cache_host' => $cache_host);
    push @writeParam, ('cache_port' => $cache_port);
    push @writeParam, ('cache_user' => $cache_user);
    push @writeParam, ('cache_passwd' => $cache_passwd);

    push @writeParam, ('memory' => $self->_cache_mem);
    push @writeParam, ('max_object_size' => $self->_max_object_size);
    push @writeParam, ('notCachedDomains'=> $self->_notCachedDomains());
    push @writeParam, ('cacheDirSize'     => $cacheDirSize);
    push @writeParam, ('principal' => $krbPrincipal);
    push @writeParam, ('realm'     => $krbRealm);

    push @writeParam, ('dn' => $dn);

    my $globalRO = EBox::Global->getInstance(1);
    if ($globalRO->modExists('remoteservices')) {
        my $rs = $globalRO->modInstance('remoteservices');
        push(@writeParam, ('snmpEnabled' => $rs->eBoxSubscribed()));
    }
    if ($removeAds) {
        push @writeParam, (urlRewriteProgram => BLOCK_ADS_PROGRAM);
        my @adsParams = ();
        push(@adsParams, ('postMatch' => $self->getAdBlockPostMatch()));
        $self->writeConfFile(ADZAPPER_CONF, 'squid/adzapper.conf.mas', \@adsParams);
    }

    $self->writeConfFile(SQUIDCONFFILE, 'squid/squid.conf.mas', \@writeParam, { mode => '0640'});

    $self->writeConfFile(SQUIDCSSFILE, 'squid/errorpage.css', []);
}

sub _objectsDelayPools
{
    my ($self) = @_;

    my @delayPools = @{$self->model('DelayPools')->delayPools()};
    return \@delayPools;
}

sub _localnets
{
    my ($self) = @_;

    my $network = $self->global()->modInstance('network');
    my $ifaces = $network->InternalIfaces();
    my @localnets;
    for my $iface (@{$ifaces}) {
        my $ifaceNet = $network->ifaceNetwork($iface);
        my $ifaceMask = $network->ifaceNetmask($iface);
        next unless ($ifaceNet and $ifaceMask);
        my $net = to_network_with_mask($ifaceNet, $ifaceMask);
        push (@localnets, $net);
    }

    return \@localnets;
}

sub _writeDgConf
{
    my ($self) = @_;

    # FIXME - get a proper lang name for the current locale
    my $lang = $self->_DGLang();

    my @dgProfiles = @{ $self->_dgProfiles };

    my @writeParam = ();

    push(@writeParam, 'port' => DGPORT);
    push(@writeParam, 'lang' => $lang);
    push(@writeParam, 'squidport' => $self->port);
    push(@writeParam, 'weightedPhraseThreshold' => $self->_banThresholdActive);
    push(@writeParam, 'nGroups' => scalar @dgProfiles);

    my $antivirus = $self->_antivirusNeeded(\@dgProfiles);
    push(@writeParam, 'antivirus' => $antivirus);

    my $maxchildren = EBox::Config::configkey('maxchildren');
    push(@writeParam, 'maxchildren' => $maxchildren);

    my $minchildren = EBox::Config::configkey('minchildren');
    push(@writeParam, 'minchildren' => $minchildren);

    my $minsparechildren = EBox::Config::configkey('minsparechildren');
    push(@writeParam, 'minsparechildren' => $minsparechildren);

    my $preforkchildren = EBox::Config::configkey('preforkchildren');
    push(@writeParam, 'preforkchildren' => $preforkchildren);

    my $maxsparechildren = EBox::Config::configkey('maxsparechildren');
    push(@writeParam, 'maxsparechildren' => $maxsparechildren);

    my $maxagechildren = EBox::Config::configkey('maxagechildren');
    push(@writeParam, 'maxagechildren' => $maxagechildren);

    $self->writeConfFile(DGDIR . '/dansguardian.conf',
            'squid/dansguardian.conf.mas', \@writeParam);

    # disable banned, exception phrases lists, regex URLs and PICS ratings
    $self->writeConfFile(DGLISTSDIR . '/bannedphraselist',
                         'squid/bannedphraselist.mas', []);

    $self->writeConfFile(DGLISTSDIR . '/exceptionphraselist',
                         'squid/exceptionphraselist.mas', []);

    $self->writeConfFile(DGLISTSDIR . '/pics',
                         'squid/pics.mas', []);

    $self->writeConfFile(DGLISTSDIR . '/bannedregexpurllist',
                         'squid/bannedregexpurllist.mas', []);

    $self->writeDgGroups();

    if ($antivirus) {
        my $avMod = $self->global()->modInstance('antivirus');
        $self->writeConfFile(CLAMD_SCANNER_CONF_FILE,
                             'squid/clamdscan.conf.mas',
                             [ clamdSocket => $avMod->localSocket() ]);
    }

    foreach my $group (@dgProfiles) {
        my $number = $group->{number};
        my $policy = $group->{policy};

        @writeParam = ();

        push(@writeParam, 'group' => $number);
        push(@writeParam, 'policy' => $policy);
        push(@writeParam, 'antivirus' => $group->{antivirus});
        push(@writeParam, 'threshold' => $group->{threshold});
        push(@writeParam, 'groupName' => $group->{groupName});
        push(@writeParam, 'defaults' => $group->{defaults});
        EBox::Module::Base::writeConfFileNoCheck(DGDIR . "/dansguardianf$number.conf",
                'squid/dansguardianfN.conf.mas', \@writeParam);

        if ($policy eq 'filter') {
            EBox::Module::Base::writeConfFileNoCheck(DGLISTSDIR . "/bannedextensionlist$number",
                                                     'squid/bannedextensionlist.mas',
                                                     [ 'extensions'  => $group->{bannedExtensions} ]);

            EBox::Module::Base::writeConfFileNoCheck(DGLISTSDIR . "/bannedmimetypelist$number",
                                                     'squid/bannedmimetypelist.mas',
                                                     [ 'mimeTypes' => $group->{bannedMIMETypes} ]);

            $self->_writeDgDomainsConf($group);
        }
    }

    $self->_writeCronFile();
    $self->_writeDgTemplates();
    $self->writeConfFile(DG_LOGROTATE_CONF, 'squid/dansguardian.logrotate', []);
}

sub _writeCronFile
{
    my ($self) = @_;

    my $times;
    my @cronTimes;

    my $rules = $self->model('AccessRules');
    foreach my $profile (@{$rules->filterProfiles()}) {
        next unless $profile->{timePeriod};
        if ($profile->{policy} eq 'deny') {
            # this is managed in squid, we don't need to rewrite DG files for it
            next;
        }
        foreach my $day (keys %{$profile->{days}}) {
            my @times;
            # if the profile only has days, we change it at new day (00:00)
            push @times, $profile->{begin} ? $profile->{begin} : '00:00';
            if ($profile->{end}) {
                push @times, $profile->{end};
            }
            foreach my $time (@times) {
                unless (exists $times->{$time}) {
                    $times->{$time} = {};
                }
                $times->{$time}->{$day} = 1;
            }
        }
    }

    foreach my $time (keys %{$times}) {
        my ($hour, $min) = split (':', $time);
        my $days = join (',', sort (keys %{$times->{$time}}));
        push (@cronTimes, { days => $days, hour => $hour, min => $min });
    }

    $self->writeConfFile(CRONFILE, 'squid/zentyal-squid.cron.mas', [ times => \@cronTimes ]);
}

sub writeDgGroups
{
    my ($self) = @_;

    my $rules = $self->model('AccessRules');
    my @profiles = @{$rules->filterProfiles()};
    my @groups;
    my @objects;
    my $anyAddressProfileSeen;

    my (undef, $min, $hour, undef, undef, undef, $day) = localtime();

    foreach my $profile (@profiles) {
        if ($profile->{policy} eq 'deny') {
            # this is stopped in squid, nothing to do
            next;
        }
        if ($profile->{timePeriod}) {
            unless ($profile->{days}->{$day}) {
                next;
            }
            if ($profile->{begin}) {
                my ($beginHour, $beginMin) = split (':', $profile->{begin});
                if ($hour < $beginHour) {
                    next;
                } elsif (($hour == $beginHour) and ($min < $beginMin)) {
                    next;
                }
            }

            if ($profile->{end}) {
                my ($endHour, $endMin) = split (':', $profile->{end});
                if ($hour > $endHour) {
                    next;
                } elsif (($hour == $endHour) and ($min > $endMin)) {
                    next;
                }
            }

        }
        if ($profile->{anyAddress}) {
            if ($anyAddressProfileSeen) {
                next;
            }
            $anyAddressProfileSeen  = 1;
            push @objects, $profile;
        }  elsif ($profile->{group}) {
            push (@groups, $profile);
        } else {
            push (@objects, $profile);
        }
    }

    $self->writeConfFile(DGLISTSDIR . '/filtergroupslist',
                         'squid/filtergroupslist.mas',
                         [ groups => \@groups ]);

    $self->writeConfFile(DGLISTSDIR . '/authplugins/ipgroups',
                         'squid/ipgroups.mas',
                         [ objects => \@objects ]);
}

# FIXME: template format has changed, reimplement this
sub _writeDgTemplates
{
    my ($self) = @_;

    my $lang = $self->_DGLang();
    my $file = DGDIR . '/languages/' . $lang . '/template.html';

    my $extra_messages = '';
    my $edition = $self->global()->edition();

    if (($edition eq 'community') or ($edition eq 'basic')) {
        $extra_messages = __sx('This is an unsupported Community Edition. Get the fully supported {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch} for automatic security updates.',
                               ohs => '<a href="https://store.zentyal.com/small-business-edition.html/?utm_source=zentyal&utm_medium=proxy.blockpage&utm_campaign=smallbusiness_edition">',
                               ohe => '<a href="https://store.zentyal.com/enterprise-edition.html/?utm_source=zentyal&utm_medium=proxy.blockpage&utm_campaign=enterprise_edition">',
                               ch => '</a>');
    }

    EBox::Module::Base::writeConfFileNoCheck($file,
                                             'squid/template.html.mas',
                                             [
                                                extra_messages => $extra_messages,
                                                image_name => "zentyal-$edition.png",
                                             ]);
}

sub _banThresholdActive
{
    my ($self) = @_;

    my @dgProfiles = @{ $self->_dgProfiles };
    foreach my $group (@dgProfiles) {
        if ($group->{threshold} > 0) {
            return 1;
        }
    }

    return 0;
}

sub _notCachedDomains
{
    my ($self) = @_;

    my $model = $self->model('NoCacheDomains');
    return $model->notCachedDomains();
}

sub _dgProfiles
{
    my ($self) = @_;

    my $profileModel = $self->model('FilterProfiles');
    return $profileModel->profiles();
}

sub _writeDgDomainsConf
{
    my ($self, $group) = @_;

    my $number = $group->{number};

    my @domainsFiles = ('bannedsitelist', 'bannedurllist',
                        'greysitelist', 'greyurllist',
                        'exceptionsitelist', 'exceptionurllist');

    foreach my $file (@domainsFiles) {
        next if (exists $group->{defaults}->{$file});

        my $path = DGLISTSDIR . '/' . $file . $number;
        my $template = "squid/$file.mas";
        EBox::Module::Base::writeConfFileNoCheck($path,
                                                 $template,
                                                 $group->{$file});
    }
}

sub firewallHelper
{
    my ($self) = @_;
    my $ro = $self->isReadOnly();

    if ($self->isEnabled()) {
        return new EBox::SquidFirewall(ro => $ro);
    }

    return undef;
}

# Method: menu
#
#       Overrides EBox::Module method.
#
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Squid',
                                        'text' => $self->printableName(),
                                        'separator' => 'Gateway',
                                        'order' => 210);

    $folder->add(new EBox::Menu::Item('url' => 'Squid/Composite/General',
                                      'text' => __('General Settings')));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/AccessRules',
                                      'text' => __(q{Access Rules})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/FilterProfiles',
                                      'text' => __(q{Filter Profiles})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/CategorizedLists',
                                      'text' => __(q{Categorized Lists})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/DelayPools',
                                      'text' => __(q{Bandwidth Throttling})));

    $root->add($folder);
}

#  Method: _daemons
#
#   Override <EBox::ServiceModule::ServiceInterface::_daemons>
#
#
sub _daemons
{
    return [
        {
            'name' => 'squid3'
        },
        {
            'name' => 'ebox.dansguardian',
            'precondition' => \&filterNeeded
        }
    ];
}

# Impelment LogHelper interface
sub tableInfo
{
    my ($self) = @_;

    my $titles = { 'timestamp'  => __('Date'),
                   'remotehost' => __('Host'),
                   'rfc931'     => __('User'),
                   'url'        => __('URL'),
                   'domain'     => __('Domain'),
                   'bytes'      => __('Bytes'),
                   'mimetype'   => __('Mime/type'),
                   'event'      => __('Event')
                 };
    my @order = ( 'timestamp', 'remotehost', 'rfc931', 'url', 'domain',
                  'bytes', 'mimetype', 'event');

    my $events = { 'accepted' => __('Accepted'),
                   'denied' => __('Denied'),
                   'filtered' => __('Filtered') };
    return [{
            'name' => __('HTTP Proxy'),
            'tablename' => 'squid_access',
            'titles' => $titles,
            'order' => \@order,
            'filter' => ['url', 'domain', 'remotehost', 'rfc931'],
            'events' => $events,
            'eventcol' => 'event',
            'consolidate' => $self->_consolidateConfiguration(),
           }];
}


sub _consolidateConfiguration
{
    my ($self) = @_;

    my $traffic = {
                   accummulateColumns => {
                                          requests => 1,
                                          accepted => 0,
                                          accepted_size => 0,
                                          denied   => 0,
                                          denied_size => 0,
                                          filtered => 0,
                                          filtered_size => 0,
                                         },
                   consolidateColumns => {
                       rfc931 => {},
                       event => {
                                 conversor => sub { return 1 },
                                 accummulate => sub {
                                     my ($v) = @_;
                                     return $v;
                                   },
                                },
                       bytes => {
                                 # size is in Kb
                                 conversor => sub {
                                     my ($v)  = @_;
                                     return sprintf("%i", $v/1024);
                                 },
                                 accummulate => sub {
                                     my ($v, $row) = @_;
                                     my $event = $row->{event};
                                     return $event . '_size';
                                 }
                                },
                     },
                   quote => {
                             'rfc931' => 1,
                            }
                  };

    return {
            squid_traffic => $traffic,

           };
}

sub logHelper
{
    my ($self) = @_;
    return (new EBox::Squid::LogHelper);
}

# Overrides:
#   EBox::Report::DiskUsageProvider::_facilitiesForDiskUsage
sub _facilitiesForDiskUsage
{
    my ($self) = @_;

    my $cachePath          = '/var/spool/squid3';
    my $cachePrintableName = 'HTTP Proxy cache';

    return { $cachePrintableName => [ $cachePath ] };

}

# Method to return the language to use with DG depending on the locale
# given by EBox
sub _DGLang
{
    my $locale = EBox::locale();
    my $lang = 'ukenglish';

    # TODO: Make sure this list is not obsolete
    my %langs = (
                 'da' => 'danish',
                 'de' => 'german',
                 'es' => 'arspanish',
                 'fr' => 'french',
                 'it' => 'italian',
                 'nl' => 'dutch',
                 'pl' => 'polish',
                 'pt' => 'portuguese',
                 'sv' => 'swedish',
                 'tr' => 'turkish',
                );

    $locale = substr($locale,0,2);
    if ( exists $langs{$locale} ) {
        $lang = $langs{$locale};
    }

    return $lang;
}

# FIXME
sub aroundDumpConfigDISABLED
{
    my ($self, $dir, %options) = @_;

    my $backupCategorizedDomainLists =
        EBox::Config::boolean('backup_domain_categorized_lists');

    my $bugReport = $options{bug};
    if (not $bugReport and $backupCategorizedDomainLists) {
        $self->SUPER::aroundDumpConfig($dir, %options);
    } else {
        # we don't save archive files
        $self->_dump_to_file($dir);
        $self->dumpConfig($dir, %options);
    }
}


# FIXME
sub aroundRestoreConfigDISABLED
{
    my ($self, $dir, %options) = @_;
    my $archive = $self->_filesArchive($dir);
    my $archiveExists = (-r $archive);
    if ($archiveExists) {
        # normal procedure with restore files
        $self->SUPER::aroundRestoreConfig($dir, %options);
    } else {
        EBox::info("Backup without domains categorized lists. Domain categorized list configuration will be removed");
        $self->_load_from_file($dir);
        $options{removeCategorizedDomainLists} = 1;
        $self->restoreConfig($dir, %options);
    }
}

# FIXME
sub restoreConfigDISABLED
{
    my ($self, $dir, %options) = @_;

    my $removeCategorizedDomainLists = $options{removeCategorizedDomainLists};
    if ($removeCategorizedDomainLists) {
        foreach my $domainFilterFiles ( @{ $self->_domainFilterFilesComponents() } ) {
            $domainFilterFiles->removeAll();
        }
    }

    $self->_cleanDomainFilterFiles(orphanedCheck => 1);
}

# LdapModule implementation
sub _ldapModImplementation
{
    return new EBox::Squid::LdapUserImplementation();
}

# Method: regenGatewaysFailover
#
# Overrides:
#
#    <EBox::NetworkObserver::regenGatewaysFailover>
#
sub regenGatewaysFailover
{
    my ($self) = @_;

    $self->restartService();
}

# Security Updates Add-On message
sub _commercialMsg
{
    return __sx('Want to avoid threats such as malware, phishing and bots? Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition {ch} that will keep your Content Filtering rules always up-to-date.',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">',
                ch => '</a>');
}

1;
