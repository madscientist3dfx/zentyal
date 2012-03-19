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

# Class: EBox::LTSP::Composite::Composite
#
#   TODO: Document composite
#

package EBox::LTSP::Composite::Composite;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#         Constructor for composite
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    return $self;
}

# Method: pageTitle
#
# Overrides:
#
#   <EBox::Model::Component::pageTitle>
#
sub pageTitle
{
    return __('Thin Clients Configuration');
}

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
{
    my $description =
    {
        components      => [
                'ClientImages',
                'Configuration',
                '/ltsp/AutoLogin',
                '/ltsp/Profiles',
            ],
        layout          => 'tabbed',
        name            => 'Composite',
        printableName   => __('Thin Clients Configuration'),
        compositeDomain => 'LTSP',
        help            => __('You will probably need to install some kind of '
                              . 'desktop environment in your server so that '
                              . 'your Thin Clients can do something useful.'),
    };

    return $description;
}

1;
