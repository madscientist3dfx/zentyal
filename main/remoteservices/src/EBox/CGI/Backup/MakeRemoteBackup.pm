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

package EBox::CGI::RemoteServices::Backup::MakeRemoteBackup;
use base qw(EBox::CGI::ClientBase  EBox::CGI::ProgressClient);

use strict;
use warnings;

use EBox::RemoteServices::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new( @_);
    $self->{errorchain} = "RemoteServices/Backup/Index";
    $self->{redirect} = "RemoteServices/Backup/Index";
    bless($self, $class);
    return $self;
}


sub requiredParameters
{
    return [qw(backup name description)];
}


sub optionalParameters
{
    return ['popup'];
}



sub actuate
{
    my ($self) = @_;

    my $backup =  new EBox::RemoteServices::Backup;

    my $name        = $self->param('name');
    my $description = $self->param('description');

    my $progress = $backup->prepareMakeRemoteBackup($name, $description);

    $self->showBackupProgress($progress);
}

my @popupProgressParams = (
        raw => 1,
        inModalbox => 1,
        nextStepType => 'submit',
        nextStepText => __('OK'),
        nextStepUrl  => '#',
        nextStepUrlOnclick => "Modalbox.hide(); window.location='/RemoteServices/Backup/Index'; return false",
);

sub showBackupProgress
{
    my ($self, $progressIndicator) = @_;

    my @params = (
                    progressIndicator  => $progressIndicator,
                    title              => __('Making remote backup'),
                    text               =>  __('Backing up modules '),
                    currentItemCaption =>  __('Operation') ,
                    itemsLeftMessage   =>  __('operations left to finish backup'),
                    endNote            =>  __('Backup successful'),
                    reloadInterval     =>  2,
                 );

    if ($self->param('popup')) {
        push @params, @popupProgressParams;
    }

    $self->showProgress(@params);
}

sub _print
{
    my ($self) = @_;
    if (not $self->param('popup')) {
        return $self->SUPER::_print();
    }

    $self->_printPopup();
}

1;
