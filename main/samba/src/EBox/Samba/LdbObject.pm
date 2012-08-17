#!/usr/bin/perl

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

package EBox::Samba::LdbObject;

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;

use Net::LDAP::LDIF;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use Net::LDAP::Control;

use Perl6::Junction qw(any);
use Error qw(:try);

# Method: new
#
#   Instance an object readed from LDB.
#
#   Parameters:
#
#      dn - Full dn for the entry
#  or
#      ldif - Net::LDAP::LDIF for the entry
#  or
#      entry - Net::LDAP entry
#
sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    unless ($params{entry} or $params{dn} or $params{ldif} or $params{samAccountName}) {
        throw EBox::Exceptions::MissingArgument('dn');
    }

    if ($params{entry}) {
        $self->{entry} = $params{entry};
    } elsif ($params{ldif}) {
        my $ldif = Net::LDAP::LDIF->new($params{ldif}, "r");
        $self->{entry} = $ldif->read_entry();
    } elsif ($params{dn}) {
        $self->{dn} = $params{dn};
    } else {
        $self->{samAccountName} = $params{samAccountName};
    }

    return $self;
}

# Method: exists
#
#   Returns 1 if the object exist, 0 if not
#
sub exists
{
    my ($self) = @_;

    # User exists if we already have its entry
    return 1 if ($self->{entry});

    $self->{entry} = $self->_entry();

    return (defined $self->{entry});
}

# Method: get
#
#   Read an user attribute
#
# Parameters:
#
#   attribute - Attribute name to read
#
sub get
{
    my ($self, $attr) = @_;

    return $self->_entry->get_value($attr);
}

# Method: set
#
#   Set an user attribute.
#
# Parameters:
#
#   attribute - Attribute name to read
#   value     - Value to set (scalar or array ref)
#   lazy      - Do not update the entry in LDAP
#
sub set
{
    my ($self, $attr, $value, $lazy) = @_;

    $self->_entry->replace($attr => $value);
    $self->save() unless $lazy;
}

# Method: add
#
#   Adds a value to an attribute without removing previous ones (if any)
#
# Parameters:
#
#   attribute - Attribute name to read
#   value     - Value to set (scalar or array ref)
#   lazy      - Do not update the entry in LDAP
#
sub add
{
    my ($self, $attr, $value, $lazy) = @_;

    $self->_entry->add($attr => $value);
    $self->save() unless $lazy;
}

# Method: delete
#
#   Deletes an attribute from the object if given
#
# Parameters (for attribute deletion):
#
#   attribute - Attribute name to read
#   lazy      - Do not update the entry in LDAP
#
sub delete
{
    my ($self, $attr, $lazy) = @_;

    if ($attr eq any $self->_entry->attributes) {
        $self->_entry->delete($attr);
        $self->save() unless $lazy;
    }
}

# Method: deleteObject
#
#   Deletes this object from the LDAP
#
sub deleteObject
{
    my ($self, $attr, $lazy) = @_;

    $self->_entry->delete();
    $self->save();
}

# Method: remove
#
#   Remove a value from the given attribute, or the whole
#   attribute if no values left
#
#   If an array ref is received as value, all the values will be
#   deleted at the same time
#
# Parameters:
#
#   attribute - Attribute name
#   value(s)  - Value(s) to remove (value or array ref to values)
#   lazy      - Do not update the entry in LDAP
#
sub remove
{
    my ($self, $attr, $value, $lazy) = @_;

    # Delete attribute only if it exists
    if ($attr eq any $self->_entry->attributes) {
        if (ref ($value) ne 'ARRAY') {
            $value = [ $value ];
        }

        $self->_entry->delete($attr, $value);
        $self->save() unless $lazy;
    }
}

# Method: save
#
#   Store all pending lazy operations (if any)
#
#   This method is only needed if some operation
#   was used using lazy flag
#
sub save
{
    my ($self, $control) = @_;

    $control = [] unless $control;
    try {
        $self->_ldap->disableZentyalModule();
        my $result = $self->_entry->update($self->_ldap->ldbCon(), control => $control);
        if ($result->is_error()) {
            if ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
                EBox::debug("Got LDAP error 'No attributes to update', ignoring it");
            } else {
                throw EBox::Exceptions::External(__('There was an error updating LDAP: ') . $result->error());
            }
        }
    } otherwise {
        my $error = shift;
        throw $error;
    } finally {
        $self->_ldap->enableZentyalModule();
    };
}

# Method: dn
#
#   Return DN for this object
#
sub dn
{
    my ($self) = @_;

    return $self->_entry->dn();
}

# Method: baseDn
#
#   Return base DN for this object
#
sub baseDn
{
    my ($self) = @_;

    my ($trash, $basedn) = split(/,/, $self->dn(), 2);
    return $basedn;
}

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the user
#
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry}) {
        my $result = undef;
        if (defined $self->{dn}) {
            my ($filter, $basedn) = split(/,/, $self->{dn}, 2);
            my $attrs = {
                base => $basedn,
                filter => $filter,
                scope => 'one',
            };
            $result = $self->_ldap->search($attrs);
        } elsif (defined $self->{samAccountName}) {
            my $attrs = {
                base => $self->_ldap->dn(),
                filter => "(samAccountName=$self->{samAccountName})",
                scope => 'sub',
            };
            $result = $self->_ldap->search($attrs);
        }

        my $name = defined $self->{dn} ? $self->{dn} : $self->{samAccountName};
        if ($result->count() > 1) {
            throw EBox::Exceptions::Internal(
                __x('Found {count} results for, expected only one.',
                    count => $result->count(), name => $name));
        }

        $self->{entry} = $result->entry(0);
    }

    return $self->{entry};
}

# Method: _ldap
#
#   Returns the LDAP object
#
sub _ldap
{
    my ($self) = @_;

    return EBox::Global->modInstance('samba')->ldb();
}

# Method: to_ldif
#
#   Returns a string containing the LDAP entry as LDIF
#
sub as_ldif
{
    my ($self) = @_;

    return $self->_entry->ldif(change => 0);
}

sub sid
{
    my ($self) = @_;

    my $sid = $self->get('objectSid');
    my $sidString = $self->_sidToString($sid);
    return $sidString;
}

sub _sidToString
{
    my ($self, $sid) = @_;

    return undef
        unless unpack("C", substr($sid, 0, 1)) == 1;

    return undef
        unless length($sid) == 8 + 4 * unpack("C", substr($sid, 1, 1));

    my $sid_str = "S-1-";

    $sid_str .= (unpack("C", substr($sid, 7, 1)) +
                (unpack("C", substr($sid, 6, 1)) << 8) +
                (unpack("C", substr($sid, 5, 1)) << 16) +
                (unpack("C", substr($sid, 4, 1)) << 24));

    for my $loop (0 .. unpack("C", substr($sid, 1, 1)) - 1) {
        $sid_str .= "-" . unpack("I", substr($sid, 4 * $loop + 8, 4));
    }

    return $sid_str;
}

sub _stringToSid
{
    my ($self, $sidString) = @_;

    return undef
        unless uc(substr($sidString, 0, 4)) eq "S-1-";

    my ($auth_id, @sub_auth_id) = split(/-/, substr($sidString, 4));

    my $sid = pack("C4", 1, $#sub_auth_id + 1, 0, 0);

    $sid .= pack("C4", ($auth_id & 0xff000000) >> 24, ($auth_id &0x00ff0000) >> 16,
            ($auth_id & 0x0000ff00) >> 8, $auth_id &0x000000ff);

    for my $loop (0 .. $#sub_auth_id) {
        $sid .= pack("I", $sub_auth_id[$loop]);
    }

    return $sid;
}

sub _guidToString
{
    my ($self, $guid) = @_;

    return sprintf "%08X-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X",
           unpack("I", $guid),
           unpack("S", substr($guid, 4, 2)),
           unpack("S", substr($guid, 6, 2)),
           unpack("C", substr($guid, 8, 1)),
           unpack("C", substr($guid, 9, 1)),
           unpack("C", substr($guid, 10, 1)),
           unpack("C", substr($guid, 11, 1)),
           unpack("C", substr($guid, 12, 1)),
           unpack("C", substr($guid, 13, 1)),
           unpack("C", substr($guid, 14, 1)),
           unpack("C", substr($guid, 15, 1));
}

sub _stringToGuid
{
    my ($self, $guidString) = @_;

    return undef
        unless $guidString =~ /([0-9,a-z]{8})-([0-9,a-z]{4})-([0-9,a-z]{4})-([0-9,a-z]{2})([0-9,a-z]{2})-([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})/i;

    return pack("I", hex $1) . pack("S", hex $2) . pack("S", hex $3) .
           pack("C", hex $4) . pack("C", hex $5) . pack("C", hex $6) .
           pack("C", hex $7) . pack("C", hex $8) . pack("C", hex $9) .
           pack("C", hex $10) . pack("C", hex $11);
}

sub _checkAccountName
{
    my ($self, $name, $maxLength) = @_;

    my $advice = undef;

    if ($name =~ m/\.$/) {
        $advice = __('Windows account names cannot end with a period');
    }

    if ($name =~ m/^[[:space:]0-9\.]+$/) {
        $advice = __('Windows account names cannot be only spaces, numbers and dots');
    }

    unless ($name =~ /^([a-zA-Z\d\s_-]+\.)*[a-zA-Z\d\s_-]+$/) {
        $advice = __('To avoid problems, the account name should ' .
                'consist only of letters, digits, underscores, ' .
                'spaces, periods, dashs, not start with a ' .
                'dash and not end with dot');
    }

    if (length ($name) > $maxLength) {
        $advice = __x("Account name must not be longer than {maxLength} characters",
                       maxLength => $maxLength);
    }

    if (defined $advice) {
        throw EBox::Exceptions::InvalidData(
                'data' => __('samAccountName'),
                'value' => $name,
                'advice' => $advice);
    }
}

sub setCritical
{
    my ($self, $critical, $lazy) = @_;

    if ($critical) {
        $self->set('isCriticalSystemObject', 'TRUE', 1);
    } else {
        $self->delete('isCriticalSystemObject', 1);
    }

    my $relaxOidControl = Net::LDAP::Control->new(
        type => '1.3.6.1.4.1.4203.666.5.12',
        critical => 0 );
    $self->save($relaxOidControl) unless $lazy;
}

1;
