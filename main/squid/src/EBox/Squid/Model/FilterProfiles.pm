# Copyright (C) 2009-2012 eBox Technologies S.L.
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

package EBox::Squid::Model::FilterProfiles;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Squid::Types::TimePeriod;
use EBox::Types::HasMany;
use EBox::Squid::Model::DomainFilterFiles;

use constant MAX_DG_GROUP => 99; # max group number allowed by dansguardian

use constant SB_URL => 'https://store.zentyal.com/small-business-edition.html/?utm_source=zentyal&utm_medium=proxy&utm_campaign=smallbusiness_edition';
use constant ENT_URL => 'https://store.zentyal.com/enterprise-edition.html/?utm_source=zentyal&utm_medium=proxy&utm_campaign=enterprise_edition';

# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::Squid::Model::GroupPolicy> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;
    return $self;
}

# Method: viewCustomizer
#
#      To display a permanent message
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = $self->SUPER::viewCustomizer();

    my $securityUpdatesAddOn = 0;
    if ( EBox::Global->modExists('remoteservices') ) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $securityUpdatesAddOn = $rs->securityUpdatesAddOn();
    }

    unless ( $securityUpdatesAddOn ) {
        $customizer->setPermanentMessage($self->_commercialMsg(), 'ad');
    }

    return $customizer;
}

# Method: _table
#
#
sub _table
{
    my ($self) = @_;

    my $dataTable =
    {
        tableName          => 'FilterProfiles',
        pageTitle          => __('HTTP Proxy'),
        printableTableName => __('Filter Profiles'),
        modelDomain        => 'Squid',
        defaultActions => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => $self->tableHeader(),
        class              => 'dataTable',
        rowUnique          => 1,
        automaticRemove    => 1,
        printableRowName   => __("filter profile"),
        messages           => {
            add => __(q{Added filter profile}),
            del =>  __(q{Removed filter profile}),
            update => __(q{Updated filter profile}),
        },
    };
}


sub tableHeader
{
    my ($self) = @_;

    my @header = (
            new EBox::Types::Text(
                fieldName => 'name',
                printableName => __('Filter group'),
                editable      => 1,
            ),
            new EBox::Types::HasMany(
                fieldName => 'filterPolicy',
                printableName => __('Configuration'),

                foreignModel => 'squid/ProfileConfiguration',
                foreignModelIsComposite => 1,

                view => '/Squid/Composite/ProfileConfiguration',
                backView => '/Squid/View/FilterProfiles',
            ),
    );

    return \@header;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (($self->size() + 1)  == MAX_DG_GROUP) {
        throw EBox::Exceptions::External(
                __('Maximum number of filter groups reached')
                );
    }

    my $name = exists $params_r->{name} ?
                      $params_r->{name}->value() :
                      $actual_r->{name}->value();

    # no whitespaces allowed in profile name
    if ($name =~ m/\s/) {
        throw EBox::Exceptions::External(__('No spaces are allowed in profile names'));
    }
}

# Method: idByRowId
#
#  Returns:
#  hash with row IDs as key and the filter group id number as value
sub idByRowId
{
    my ($self) = @_;
    my %idByRowId;
    my $id = 0;
    foreach my $rowId (@{ $self->ids()  }) {
        $id += 1;
        $idByRowId{$rowId} = $id;
    }

    return \%idByRowId;
}

sub profiles
{
    my ($self) = @_;
    my @profiles = ();

    my $squid = EBox::Global->modInstance('squid');
    my $usergroupPolicies = $squid->model('GlobalGroupPolicy');
    my %usersByProfileId = %{ $usergroupPolicies->usersByProfile()  };

    # groups will have ids greater that this number
    my $id = 0;

    # remember id 1 is reserved for gd's default group so it must be
    # the first to be getted
    foreach my $rowId ( @{ $self->ids() } ) {
        my $row = $self->row($rowId);
        my $name  = $row->valueByName('name');

        $id += 1;
        if ($id > MAX_DG_GROUP) {
            EBox::info("Filter group $name and following groups will use default content filter policy because the maximum number of Dansguardian groups is reached");
            last;
        }

        my $users;
        if (exists $usersByProfileId{$rowId}) {
            $users = $usersByProfileId{$rowId};
        } else {
            $users = [];
        }

        my %group = (
                number => $id,
                groupName => $name,
                users  => $users,
                defaults => {},
                );

        my $policy = $row->elementByName('filterPolicy')->foreignModelInstance();

        $group{antivirus} = $policy->componentByName('AntiVirus', 1)->active(),

        $group{threshold} = $policy->componentByName('ContentFilterThreshold', 1)->threshold();

        $group{bannedExtensions} = $policy->componentByName('Extensions', 1)->banned();

        $group{bannedMIMETypes} = $policy->componentByName('MIME', 1)->banned();

        $self->_setProfileDomainsPolicy(\%group, $policy);

        push @profiles, \%group;
    }

    return \@profiles;
}


sub _setProfileDomainsPolicy
{
    my ($self, $group, $policy) = @_;

    my $domainFilter      = $policy->componentByName('DomainFilter', 1);
    my $domainFilterFiles = $policy->componentByName('DomainFilterFiles', 1);

    $group->{exceptionsitelist} = [
                                   domains => $domainFilter->allowed(),
                                   includes => $domainFilterFiles->allowed(),
                                  ];

    $group->{exceptionurllist} = [
                                  urls =>  $domainFilter->allowedUrls(),
                                  includes => $domainFilterFiles->allowedUrls(),
                                 ];

    $group->{greysitelist} = [
                              domains => $domainFilter->filtered(),
                              includes => $domainFilterFiles->filtered(),
                             ];

    $group->{greyurllist} = [
                             urls => $domainFilter->filteredUrls(),
                             includes => $domainFilterFiles->filteredUrls(),
                            ];

    $group->{bannedurllist} = [
                               urls =>  => $domainFilter->bannedUrls(),
                               includes => $domainFilterFiles->bannedUrls(),
                              ];

    my $domainFilterSettings = $policy->componentByName('DomainFilterSettings', 1);

    $group->{bannedsitelist} = [
                                blockIp       => $domainFilterSettings->blockIpValue,
                                blanketBlock  => $domainFilterSettings->blanketBlockValue,
                                domains       => $domainFilter->banned(),
                                includes      => $domainFilterFiles->banned(),
                               ];
}

sub antivirusNeeded
{
    my ($self) = @_;

    my $id = 0;
    foreach my $rowId ( @{ $self->ids() } ) {
        my $antivirusModel;
        my $row = $self->row($rowId);
        next unless defined ($row);
        my $policy =
            $row->elementByName('filterPolicy')->foreignModelInstance();

        if ($id > MAX_DG_GROUP) {
            my $name  = $row->valueByName('name');
            EBox::info(
                    "Maximum nuber of dansguardian groups reached, group $name and  following groups antivirus configuration is not used"
                    );
            last;
        } else {
            $antivirusModel =
                $policy->componentByName('AntiVirus', 1);
        }

        if ($antivirusModel->active()) {
            return 1;
        }

        $id += 1 ;
    }

    # no profile with antivirus enabled found...
    return 0;
}

# this must be only called one time
sub restoreConfig
{
    my ($class, $dir)  = @_;
    EBox::Squid::Model::DomainFilterFiles->restoreConfig($dir);
}

# Security Updates Add-On message
sub _commercialMsg
{
    return __sx('Want to avoid threats such as malware, phishing and bots? Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition {ch} that include the Content Filtering feature in the automatic security updates.',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">',
                ch => '</a>');
}

1;
