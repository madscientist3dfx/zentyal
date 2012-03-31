# Copyright (C) 2011-2012 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::Model::TechnicalInfo
#
# This class is the model to show information about technical support
#
#     - server name
#     - server edition
#     - support via
#     - SLA
#

package EBox::RemoteServices::Model::TechnicalInfo;

use strict;
use warnings;

use base 'EBox::Model::DataForm::ReadOnly';

use v5.10;

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Types::EBoxCommonName;
use EBox::Types::Text;
use EBox::Types::HTML;
use POSIX;

# Constants:
use constant STORE_URL => 'http://store.zentyal.com/';
use constant SB_URL  => STORE_URL . 'small-business-edition/?utm_source=zentyal&utm_medium=subscription.techinfo&utm_campaign=smallbusiness_edition';
use constant ENT_URL   => STORE_URL . 'enterprise-edition/?utm_source=zentyal&utm_medium=subscripiton.techinfo&utm_campaign=enterprise_edition';

# Group: Public methods

# Constructor: new
#
#     Create the subscription form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::RemoteServices::Model::TechnicalInfo>
#
sub new
{

    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class);

    return $self;

}
# Method: viewCustomizer
#
#      Return a custom view customizer to set a permanent message if
#      the technical support is not purchased
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    my $rs = $self->{gconfmodule};
    if ( $rs->technicalSupport() < 0 ) {
        $customizer->setPermanentMessage(_message(), 'ad');
    }
    return $customizer;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
          new EBox::RemoteServices::Types::EBoxCommonName(
              fieldName     => 'server_name',
              printableName => __('Server name'),
             ),
          new EBox::Types::Text(
              fieldName     => 'edition',
              printableName => __('Server edition'),
             ),
          new EBox::Types::HTML(
              fieldName     => 'support_via',
              printableName => __('Support available via'),
             ),
          new EBox::Types::Text(
              fieldName     => 'sla',
              printableName => __('Service Level Agreement'),
             ),
      );

    my $dataForm = {
                    tableName          => __PACKAGE__->nameFromClass(),
                    printableTableName => __('Technical Support'),
                    modelDomain        => 'RemoteServices',
                    tableDescription   => \@tableDesc,
                };

    return $dataForm;
}

# Method: _content
#
# Overrides:
#
#    <EBox::Model::DataForm::ReadOnly::_content>
#
sub _content
{
    my ($self) = @_;

    my $rs = $self->{gconfmodule};

    my ($serverName, $subscription, $supportVia, $sla) =
      (__('None'), __('None'),
       '<span>' . __('None') . '</span>', __('None'));

    if ( $rs->eBoxSubscribed() ) {
        $serverName = $rs->eBoxCommonName();

        $subscription = $rs->i18nServerEdition();

        my $techSupportLevel = $rs->technicalSupport();
        if ( $techSupportLevel >= 0 ) {
            my %i18nVia = ( '0'  => __sx('{oh}On-line Support Platform{ch}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>'),
                            '1'  => __sx('{os}{oh}On-line Support Platform{ch}, Chat and Phone upon request{cs}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>',
                                         os => '<span>',
                                         cs => '</span>'),
                            '2'  => __sx('{os}{oh}On-line Support Platform{ch}, Chat'
                                         . ', Phone{cs}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>',
                                         os => '<span>',
                                         cs => '</span>')
                           );
            $supportVia = $i18nVia{$techSupportLevel};

            my %i18nSLA = ( '0' => __s('Next Business Day'),
                            '1' => __s('4 hours'),
                            '2' => __s('1 hour') );
            $sla = $i18nSLA{$techSupportLevel};
        }

    }

    return {
        server_name  => $serverName,
        edition      => $subscription,
        support_via  => $supportVia,
        sla          => $sla,
       };
}

# Group: Private methods

sub _message
{
    return __sx('Want to install and configure your server correctly right from the start and receive maintenance support whenever necessary? Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch}: both include technical support for an unlimited number of Zentyal server related issues.',
                ch => '</a>',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">');
}

1;
