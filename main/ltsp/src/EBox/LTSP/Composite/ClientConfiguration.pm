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

# Class: EBox::LTSP::Composite::Configuration
#
#   TODO: Document composite
#

package EBox::LTSP::Composite::ClientConfiguration;

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
    return 'Profile Configuration';
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
                '/ltsp/GeneralClientOpts',
                '/ltsp/OtherClientOpts',
            ],
        layout          => 'top-bottom',
        name            => 'ClientConfiguration',
        printableName   => __('Client Configuration'),
        compositeDomain => 'LTSP',
        #help            => __(''), # FIXME
    };

    return $description;
}

sub HTMLTitle
{
    my ($self) = @_;

    my $row  = $self->parentRow();
    my $profile = $row->printableValueByName('name');

    return [
        {
            title => $profile,
            link  => '/LTSP/Composite/Composite#Profiles',
        },
        {
            title => $self->printableName(),
            link  => ''
        }
    ];
}

1;
