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
use strict;
use warnings;

package EBox::CGI::SysInfo::ConfirmBackup;
use base 'EBox::CGI::ClientBase';

use EBox::Config;
use EBox::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Configuration Backup'),
                                  'template' => '/confirm-backup.mas',
                                  @_);
    $self->{errorchain} = "SysInfo/Backup";

    bless($self, $class);
    return $self;
}

sub requiredParameters
{
  my ($self) = @_;

  if ($self->param('download.x')) {
    return [qw(id download.x download.y)];
  }  elsif ($self->param('delete.x')) {
    return [qw(id delete.x delete.y)];
  }  elsif ($self->param('delete')) {
    return [qw(id delete)];
  }  elsif ($self->param('restoreFromId.x')) {
    return [qw(restoreFromId.x restoreFromId.y id)];
  }  elsif ($self->param('restoreFromId')) {
    return [qw(restoreFromId id)];
  }  elsif ($self->param('restoreFromFile')) {
    return [qw(restoreFromFile backupfile)];
  }

  return [];
}

sub optionalParameters
{
    return ['download', 'delete', 'popup'];
}


sub actuate
{
  my ($self) = @_;

  if (defined($self->param('download.x'))) {
    $self->{chain} = 'SysInfo/Backup';
    return;
  }

  foreach my $actionParam (qw(delete restoreFromId restoreFromFile )) {
    if ($self->param($actionParam)) {
      my $actionSub = $self->can($actionParam . 'Action');
      my ($backupAction, $backupActionText, $backupDetails) = $actionSub->($self);
      $self->{params} = [action => $backupAction, actiontext => $backupActionText, backup => $backupDetails];
      if ($self->param('popup')) {
          push @{ $self->{params} }, (popup => 1);
      }

      return;
    }
  }

  # otherwise...
  $self->{redirect} = "SysInfo/Backup";
  return;
}


sub masonParameters
{
  my ($self) = @_;

  if (exists $self->{params}) {
    return $self->{params};
  }

  return [];
}

sub deleteAction
{
  my ($self) = @_;

  $self->{msg} = __('Please confirm that you want to delete the following backup file:');

  return ('delete', __('Delete'), $self->backupDetailsFromId());
}

sub  restoreFromIdAction
{
  my ($self) = @_;

  $self->{msg} = __('Please confirm that you want to restore using this backup file:');

  return ('restoreFromId', __('Restore'), $self->backupDetailsFromId());
}




sub  restoreFromFileAction
{
  my ($self) = @_;

  my $filename = $self->upload('backupfile');

  my $details = $self->backupDetailsFromFile($filename);

  $self->{msg} = __('Please confirm that you want to restore using this backup file:');

  return ('restoreFromFile', __('Restore'), $details);
}





sub backupDetailsFromId
{
  my ($self) = @_;
  my $backup = new EBox::Backup;

  my $id = $self->param('id');
  if ($id =~ m{[./]}) {
    throw EBox::Exceptions::External(
                                     __("The input contains invalid characters"));
  }

  my $details =  $backup->backupDetails($id);
  $self->setPrintabletype($details);

  return $details;
}


sub backupDetailsFromFile
{
  my ($self, $filename) = @_;
  my $details = EBox::Backup->backupDetailsFromArchive($filename);

  $self->setPrintabletype($details);

  return $details;
}


sub setPrintabletype
{
  my ($self, $details_r) = @_;

  my $type = $details_r->{type};
  my $printableType;

  if ($type eq $EBox::Backup::CONFIGURATION_BACKUP_ID) {
    $printableType = __('Configuration backup');
  }
  elsif ($type eq $EBox::Backup::FULL_BACKUP_ID) {
    $printableType = __('Full data and configuration backup');
  }
  elsif ($type eq $EBox::Backup::BUGREPORT_BACKUP_ID) {
    $printableType = __('Bug-report configuration dump');
  }


  $details_r->{printableType} = $printableType;
  return $details_r;
}

# to avoid the <div id=content>
sub _print
{
    my ($self) = @_;
    if (not $self->param('popup')) {
        return $self->SUPER::_print();
    }

    my $json = $self->{json};
    if ($json) {
        $self->JSONReply($json);
        return;
    }

    $self->_header;
    print '<div id="limewrap"><div>';
    $self->_error;
    $self->_msg;
    $self->_body;
    print "</div></div>";
}

1;
