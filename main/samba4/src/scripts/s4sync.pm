#!/usr/bin/perl

use strict;

use Array::Diff;
use Net::Domain qw(hostname);
use Error qw(:try);

use EBox;
use EBox::Global;

# There users and groups won't be synchronized to LDAP
my $dnsUserToIgnore = 'dns-' . hostname();
my @sambaUsersToIgnore = ('krbtgt', 'Administrator', $dnsUserToIgnore, 'Guest');
my @sambaGroupsToIgnore = ('Read-Only Domain Controllers', 'Group Policy Creator Owners', 'Domain Controllers', 'Domain Computers', 'DnsUpdateProxy', 'Domain Admins',
                           'Domain Guests', 'Domain Users', 'Users');

# These are the users and groups ignored. All users and groups that are not in
# samba neither in this arrays will be deleted
my @ldapUsersToIgnore  = ('');
my @ldapGroupsToIgnore = ('__USERS__');

#############################################################################
## Info, error and debug helper functions                                  ##
#############################################################################
sub debug
{
    my ($msg) = @_;
#    print "$msg\n";
    EBox::debug ("$msg");
}

sub info
{
    my ($msg) = @_;
#    print "$msg\n";
    EBox::info ("$msg");
}

sub error
{
    my ($msg) = @_;
#    print "$msg\n";
    EBox::error ("$msg");
}

#############################################################################
## LDB related functions                                                   ##
#############################################################################

# Method: getSambaUsers
#
#   This method get all users stored in the LDB
#
# Parameters:
#
#   sambaModule - Instance of the zentyal samba module
#   usersToIgnore (optional) - A reference to a list containing
#       the users to ignore
#
# Returns:
#
#   A hash reference containing all found entries
#
sub getSambaUsers
{
    my ($sambaModule, $usersToIgnore) = @_;

    my $users = {};
    my $ldb = $sambaModule->ldb();
    my $result = $ldb->search({
            base   => $ldb->rootDN(),
            scope  => 'sub',
            filter => '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200))',
            attrs  => ['sAMAccountName', 'cn', 'givenName', 'sn', 'description','whenChanged']});
    my @entries = $result->entries;
    if (defined $usersToIgnore) {
        my %usersToIgnore = map { $_ => 1 } @{$usersToIgnore};
        foreach my $entry (@entries) {
            unless (exists $usersToIgnore{$entry->get_value('sAMAccountName')}) {
                $users->{$entry->get_value('sAMAccountName')} = $entry;
            }
        }
    }
    return $users;
}

# Method: getSambaGroups
#
#   This method get all groups stored in the LDB
#
# Parameters:
#
#   sambaModule - An instance of the zentyal samba module
#   groupsToIgnore (optional) - A reference to a list containing
#       the groups to ignore
#
# Returns:
#
#   A hash reference containing all found entries
#
sub getSambaGroups
{
    my ($sambaModule, $groupsToIgnore) = @_;

    my $groups = {};
    my $ldb = $sambaModule->ldb();
    my $result = $ldb->search({
            base   => $ldb->rootDN(),
            scope  => 'sub',
            filter => '(&(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002))',
            attrs  => ['sAMAccountName', 'member', 'whenChanged', 'description']});
    my @entries = $result->entries;
    if (defined $groupsToIgnore) {
        my %groupsToIgnore = map { $_ => 1 } @{$groupsToIgnore};
        foreach my $entry (@entries) {
            unless (exists $groupsToIgnore{$entry->get_value('sAMAccountName')}) {
                $groups->{$entry->get_value('sAMAccountName')} = $entry;
            }
        }
    }
    return $groups;
}

#############################################################################
## LDAP related functions                                                  ##
#############################################################################

# Method: getLdapUsers
#
#   This method get all users stored in the LDAP
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   usersToIgnore (optional) - A reference to a list containing
#       the users to ignore
#
# Returns:
#
#   A hash reference containing all found entries
#
sub getLdapUsers
{
    my ($usersModule, $usersToIgnore) = @_;

    my $users = {};
    my $result = $usersModule->{ldap}->search({
            base   => $usersModule->usersDn(),
            scope  => 'one',
            filter => 'objectClass=posixAccount',
            attrs => ['uid','modifyTimestamp']});
    my @entries = $result->entries;
    if (defined $usersToIgnore) {
        my %usersToIgnore = map { $_ => 1 } @{$usersToIgnore};
        foreach my $entry (@entries) {
            unless (exists $usersToIgnore{$entry->get_value('uid')}) {
                $users->{$entry->get_value('uid')} = $entry;
            }
        }
    }
    return $users;
}

# Method: getLdapGroups
#
#   This method get all groups stored in the LDAP
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   usersToIgnore (optional) - A reference to a list containing
#       the groups to ignore
#
# Returns:
#
#   hash reference containing all found entries
#
sub getLdapGroups
{
    my ($usersModule, $groupsToIgnore) = @_;

    my $groups = {};
    my $result = $usersModule->{ldap}->search({
            base   => $usersModule->groupsDn(),
            scope  => 'one',
            filter => 'objectClass=posixGroup',
            attrs  => ['cn', 'memberUid', 'modifyTimestamp']});
    my @entries = $result->entries;
    if (defined $groupsToIgnore) {
        my %groupsToIgnore = map { $_ => 1 } @{$groupsToIgnore};
        foreach my $entry (@entries) {
            unless (exists $groupsToIgnore{$entry->get_value('cn')}) {
                $groups->{$entry->get_value('cn')} = $entry;
            }
        }
    }
    return $groups;
}

# Method: addLdapUser
#
#   This method add a user to LDAP
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   credentials - A hash reference to the new user samba credentials
#   sambaUser - A reference to the samba user to be added (the LDB entry)
#
sub addLdapUser
{
    my ($usersModule, $credentials, $sambaUser) = @_;

    my $accountName = $sambaUser->get_value('sAMAccountName');
    if (exists $credentials->{'Primary:CLEARTEXT'}) {
        try {
            info ("Adding user '$accountName' to LDAP");
            my $params = {
                user => $accountName,
                fullname  => $sambaUser->get_value('cn'),
                password  => $credentials->{'Primary:CLEARTEXT'},
                givenname => length ($sambaUser->get_value('givenName')) > 0 ?
                    $sambaUser->get_value('givenName') :
                    $sambaUser->get_value('sAMAccountName'),
                surname   => length ($sambaUser->get_value('sn')) > 0 ?
                    $sambaUser->get_value('sn') :
                    $sambaUser->get_value('sAMAccountName'),
                comment   => $sambaUser->get_value('description'),
            };
            $usersModule->addUser($params, 0 );
        } otherwise {
            my $error = shift;
            error ("Error adding user to LDAP: $error");
        };
    } else {
        error ("Samba user '$accountName' do not added to LDAP: password not found");
    }
}

# Method: delLdapUser
#
#   This method removes a user from LDAP
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   userId - The ID of the user to remove (the sAMAccountName)
#
sub delLdapUser
{
    my ($usersModule, $userId) = @_;

    try {
        info ("Deleting user '$userId' from LDAP");
        $usersModule->delUser ($userId);
    } otherwise {
        my $error = shift;
        error ("Error deleting user from LDAP: $error");
    }
}
# Method: addLdapGroup
#
#   This method add a group to LDAP
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   sambaGroup - A reference to the samba group to be added (the LDB entry)
#
sub addLdapGroup
{
    my ($usersModule, $sambaGroup) = @_;

    try {
        my $groupName = $sambaGroup->get_value('sAMAccountName');
        my $comment = length ($sambaGroup->get_value ('description')) > 0 ?
            $sambaGroup->get_value('description') : '';
        info ("Adding group '$groupName' to LDAP");
        $usersModule->addGroup ($groupName, $comment, 0);
    } otherwise {
        my $error = shift;
        error ("Error adding group to LDAP: $error");
    }
}

# Method: delLdapGroup
#
#   This method removes a group from LDAP
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   group - The ID of the group to remove (the cn)
#
sub delLdapGroup
{
    my ($usersModule, $group) = @_;

    try {
        info ("Deleting group '$group' from ldap");
        $usersModule->delGroup ($group);
    } otherwise {
        my $error = shift;
        error ("Error deleting group from LDAP: $error");
    }
}

# Method: addLdapUserToGroup
#
#   This method add a LDAP user to a LDAP group
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   user - The name of the user
#   group - The name of the group
#
sub addLdapUserToLdapGroup
{
    my ($usersModule, $user, $group) = @_;

    try {
        info ("Adding user '$user' to group '$group' in LDAP");
        $usersModule->addUserToGroup ($user, $group);
    } otherwise {
        my $error = shift;
        error ("Error adding user '$user' to LDAP group '$group': $error");
    }
}

# Method: delLdapUserFromGroup
#
#   This method delete a LDAP user from a LDAP group
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   user - The name of the user
#   group - The name of the group
#
sub delLdapUserFromLdapGroup
{
    my ($usersModule, $user, $group) = @_;

    try {
        info ("Removing user '$user' from group '$group' in LDAP");
        $usersModule->delUserFromGroup ($user, $group);
    } otherwise {
        my $error = shift;
        error ("Error deleting user '$user' from LDAP group '$group': $error");
    }
}

# Method: updateLdapGroup
#
#   This method update the group members in LDAP
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   sambaModule - An instance of the zentyal samba module
#   sambaGroup - A reference to the LDB group entry to synchronize
#   ldapGroup - A reference to the LDAP group entry to synchronize
#
sub updateLdapGroup
{
    my ($usersModule, $sambaModule, $sambaGroup, $ldapGroup,
        $sambaUsersToIgnore, $ldapUsersToIgnore) = @_;

    # Get the group name
    my $groupId = $sambaGroup->get_value('sAMAccountName');

    # Get the samba group members and filter the samba users to ignore
    my %sambaUsersToIgnore = map { $_ => 1 } @{$sambaUsersToIgnore};
    my (@sambaMembersDN) = $sambaGroup->get_value('member');
    my @sambaMembers = ();
    foreach my $memberDN (@sambaMembersDN) {
        my $memberID = $sambaModule->ldb->getIdByDN($memberDN);
        push (@sambaMembers, $memberID) unless exists $sambaUsersToIgnore{$memberID};
    }

    # Get the ldap group members and filter the ldap users to ignore
    my %ldapUsersToIgnore = map { $_ => 1 } @{$ldapUsersToIgnore};
    my (@ldapMembersTmp) = $ldapGroup->get_value('memberUid');
    my @ldapMembers = ();
    foreach my $memberID (@ldapMembersTmp) {
        push (@ldapMembers, $memberID) unless exists $ldapUsersToIgnore{$memberID};
    }

    # Calculate the arrays difference
    # Note: The arrays must be sorted before compare them
    @sambaMembers = sort @sambaMembers;
    @ldapMembers = sort @ldapMembers;
    my $diff = Array::Diff->diff (\@ldapMembers, \@sambaMembers);

    debug ("Synchronizing group '$groupId'");
    debug ("Samba members: @sambaMembers");
    debug ("LDAP members: @ldapMembers");

    # Add the missing members to the group
    foreach my $memberId (@{$diff->added}) {
        addLdapUserToLdapGroup ($usersModule, $memberId, $groupId);
    }

    # Remove the members
    foreach my $memberId (@{$diff->deleted}) {
        delLdapUserFromLdapGroup ($usersModule, $memberId, $groupId);
    }

    # Update the group description
    try {
        $usersModule->modifyGroup({
            groupname  => $groupId,
            comment   => $sambaGroup->get_value('description')});
    } otherwise {
        my $error = shift;
        error ("Error updating group description: $error");
    }
}

# Method: updateLdapUserMembership
#
#   This method update the user information in LDAP
#
# Parameters:
#
#   usersModule - An instance of the zentyal users module
#   sambaModule - An instance of the zentyal samba module
#   sambaUser - A reference to a sambaUser (an LDB entry)
#
sub updateLdapUser
{
    my ($usersModule, $sambaModule, $sambaUser) = @_;

    my $userId = $sambaUser->get_value('sAMAccountName');
    try {
        info ("Updating user '$userId' from samba to LDAP");
        my $ldb = $sambaModule->ldb();
        my $credentials = $ldb->getSambaCredentials($userId);
        if (defined $credentials->{'Primary:CLEARTEXT'}) {
            $usersModule->modifyUser({
                username  => $userId,
                password  => $credentials->{'Primary:CLEARTEXT'},
                givenname => length ($sambaUser->get_value('givenName')) > 0 ?
                    $sambaUser->get_value('givenName') :
                    $sambaUser->get_value('sAMAccountName'),
                surname   => length ($sambaUser->get_value('sn')) > 0 ?
                    $sambaUser->get_value('sn') :
                    $sambaUser->get_value('sAMAccountName'),
                fullname  => $sambaUser->get_value('cn'),
                comment   => $sambaUser->get_value('description')});
        }
    } otherwise {
        my $error = shift;
        error ("Error updating user '$userId' in LDAP: $error");
    }
}

####################################################################################################

EBox::init();

my $usersModule = EBox::Global->modInstance('users');
my $ldapUsers = getLdapUsers ($usersModule, \@ldapUsersToIgnore);
my $ldapGroups = getLdapGroups ($usersModule, \@ldapGroupsToIgnore);

my $sambaModule = EBox::Global->modInstance('samba4');
my $sambaUsers = getSambaUsers ($sambaModule, \@sambaUsersToIgnore);
my $sambaGroups = getSambaGroups ($sambaModule, \@sambaGroupsToIgnore);

debug ("Got " . scalar(keys(%{$sambaUsers})) . " samba users and " .
        scalar(keys(%{$ldapUsers})) . " ldap users" );
debug ("Got " . scalar(keys(%{$sambaGroups})) . " samba groups and " .
        scalar(keys(%{$ldapGroups})) . " ldap groups" );

# Insert new users from Samba to LDAP
foreach my $sambaUser (keys %{$sambaUsers}) {
    # If the user exists in samba but not in LDAP insert in LDAP
    unless (exists $ldapUsers->{$sambaUser}) {
        # Get the user credentials
        my $ldb = $sambaModule->ldb();
        my $userCredentials = $ldb->getSambaCredentials($sambaUser);
        addLdapUser ($usersModule, $userCredentials, $sambaUsers->{$sambaUser});
    }
}

# Insert new groups from Samba to LDAP
foreach my $sambaGroup (keys %{$sambaGroups}) {
    # If the group exists in samba but not in LDAP insert in LDAP
    unless (exists $ldapGroups->{$sambaGroup}) {
        addLdapGroup ($usersModule, $sambaGroups->{$sambaGroup});
    }
}

# Delete users that are not in Samba
foreach my $user (keys %{$ldapUsers}) {
    # If the user exists in LDAP but not in samba, delete from LDAP
    unless (exists $sambaUsers->{$user}) {
        delLdapUser ($usersModule, $user);
    }
}

# Delete groups that are not in Samba
foreach my $group (keys %{$ldapGroups}) {
    # If the group exists in LDAP but not in samba, delete from LDAP
    unless (exists $sambaGroups->{$group}) {
        delLdapGroup ($usersModule, $group);
    }
}

# Sync user information like passwords, descriptions from Samba to LDAP
foreach my $userId (keys %{$sambaUsers}) {
    my $sambaChangeTime = $sambaUsers->{$userId}->get_value('whenChanged');
    if (exists $ldapUsers->{$userId}) {
        my $ldapChangeTime = $ldapUsers->{$userId}->get_value('modifyTimestamp');
        $sambaChangeTime =~ s/(\.\d*)?Z//g;
        $ldapChangeTime =~ s/(\.\d*)?Z//g;

        if ($sambaChangeTime > $ldapChangeTime) {
            my $user = $sambaUsers->{$userId};
            updateLdapUser ($usersModule, $sambaModule, $user);
        }
    }
}

# Sync group memberships from Samba to LDAP
foreach my $groupId (keys %{$sambaGroups}) {
    my $sambaChangeTime = $sambaGroups->{$groupId}->get_value('whenChanged');
    if (exists $ldapGroups->{$groupId}) {
        my $ldapChangeTime = $ldapGroups->{$groupId}->get_value('modifyTimestamp');
        $sambaChangeTime =~ s/(\.\d*)?Z//g;
        $ldapChangeTime =~ s/(\.\d*)?Z//g;
        if ($sambaChangeTime > $ldapChangeTime) {
            my $sambaGroup = $sambaGroups->{$groupId};
            my $ldapGroup = $ldapGroups->{$groupId};
            updateLdapGroup ($usersModule, $sambaModule, $sambaGroup, $ldapGroup,
                             \@sambaUsersToIgnore, \@ldapUsersToIgnore);
        }
    }
}
