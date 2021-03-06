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

# Class: EBox::Types::HostIP
#
#      A specialised text type to represent an host IP address, that
#      is, those IP addresses whose netmask is equal to 32
#
package EBox::Types::HostIP;

use strict;
use warnings;

use base 'EBox::Types::Text';

use EBox::Validate;

# Dependencies
use Net::IP;

# Group: Public methods

# Constructor: new
#
#      The constructor for the <EBox::Types::HostIP>
#
# Returns:
#
#      the recently created <EBox::Types::HostIP> object
#
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{'type'} = 'hostip';
    bless($self, $class);
    return $self;
}

# Method: cmp
#
# Overrides:
#
#      <EBox::Types::Abstract::cmp>
#
sub cmp
{
    my ($self, $compareType) = @_;

    unless ( (ref $self) eq (ref $compareType) ) {
        return undef;
    }

    my $ipA = new Net::IP($self->value());
    my $ipB = new Net::IP($compareType->value());

    if ( $ipA->bincomp('lt', $ipB) ) {
        return -1;
    } elsif ( $ipA->bincomp('gt', $ipB)) {
        return 1;
    } else {
        return 0;
    }
}

# Group: Protected methods

# Method: _paramIsValid
#
#     Check if the params has a correct host IP address
#
# Overrides:
#
#     <EBox::Types::Text::_paramIsValid>
#
# Parameters:
#
#     params - the HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is a correct host IP address
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       host IP address
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    if (defined ($value)) {
        EBox::Validate::checkIP($value, $self->printableName());
    }

    return 1;
}

1;
