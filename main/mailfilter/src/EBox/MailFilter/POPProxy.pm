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

package EBox::MailFilter::POPProxy;

use strict;
use warnings;


use EBox::Config;
# use EBox::Service;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Global;
use EBox;

use EBox::Dashboard::ModuleStatus;

use Perl6::Junction qw(all);
use File::Slurp qw(read_file);

use constant {
    P3SCAN_CONF_FILE => '/etc/p3scan/p3scan.conf',
    RENATTACH_CONF_FILE => '/etc/renattach/renattach.conf',

#   P3SCAN_SERVICE => 'ebox.p3scan',
    P3SCAN_BIN     => '/usr/sbin/p3scan',
    P3SCAN_INITD   => '/etc/init.d/p3scan',
    P3SCAN_PORT    => 8110,
};


sub new
{
    my $class = shift @_;

    my $self = {};
    bless $self, $class;

    return $self;
}


sub usedFiles
{
  return (
        {
         file => P3SCAN_CONF_FILE,
         reason => __(' To configure p3scan'),
         module => 'mailfilter',
        },
          {
           file => RENATTACH_CONF_FILE,
           reason => __('To configure renattach'),
           module => 'mailfilter',
          },
         );
}


sub doDaemon
{
    my ($self, $mailfilterService) = @_;

    my $enabled = $self->isEnabled();
    my $running = $self->isRunning();

    if ($enabled and $mailfilterService) {
        if ($running) {
            $self->_daemon('restart');
        }
        else {
            $self->_daemon('start');
        }
    }
    elsif ($self->isRunning()) {
      $self->_daemon('stop');
  }

}


sub pidFile
{
    return  '/var/run/p3scan/p3scan.pid';
}

# XXX p3scan doesnt pipe its output (it does not return) so we
#  cannot use this correct implementation
# sub _daemon
# {
#   my ($self, $action) = @_;

#   if ($action ne all('start', 'stop', 'restart')) {
#     throw EBox::Exceptions::Internal("Bad argument: $action");
#   }

#   EBox::Sudo::root(P3SCAN_INITD . ' stop');


#   if (($action eq 'stop') or ($action eq 'restart')) {
#       my $pid;
#       my $pidFile = $self->pidFile();

#       if (EBox::Sudo::fileTest('-e', $pidFile)) {
#           ($pid)     = @{ EBox::Sudo::root("/bin/cat $pidFile")   };
#           chomp $pid;

#           if ($pid) {
#               my $cmd = "kill $pid";
#               EBox::Sudo::root($cmd);
#           }
#           else {
#               throw EBox::Exceptions::Internal("No PID found in $pidFile");
#           }

#       }

#   }

#   if (($action eq 'start') or ($action eq 'restart')) {

#       EBox::Sudo::root(P3SCAN_BIN);
#   }

#  # XXX we cannot use services bz p3scan is unable to run in foreground for now
# #  EBox::Service::manage(P3SCAN_SERVICE, $action);
# }


sub _daemon
{
    my ($self, $action) = @_;

    if ($action ne all('start', 'stop', 'restart')) {
        throw EBox::Exceptions::Internal("Bad argument: $action");
    }

    EBox::Sudo::root(P3SCAN_INITD . ' stop');

    if (($action eq 'stop') or ($action eq 'restart')) {
        my $pid;
        my $pidFile = $self->pidFile();

        if (EBox::Sudo::fileTest('-e', $pidFile)) {
            ($pid)     = @{ EBox::Sudo::root("/bin/cat $pidFile")   };
            chomp $pid;

            if ($pid) {
                my $cmd = "kill $pid";
                EBox::Sudo::root($cmd);
            }
            else {
                throw EBox::Exceptions::Internal("No PID found in $pidFile");
            }

            # to recover from leftover pid files..
            EBox::Sudo::root("rm -f $pidFile");
        }

    }

    if (($action eq 'start') or ($action eq 'restart')) {
        # XXX for some unknown reason p3scan does not take in account the
        # 'checkspam' in config file so we need to specify it as cli switch
        #  remove this when p3scan properly manages its config file
        my $params ='';
        if ($self->antispam()) {
            $params = ' -k ';
        }

        # this is a reimplemntation of EBox::Sudo::root to avoid the stdout pipe
        my $outFile = EBox::Config::tmp() . 'p3scanstdout';
        my $errFile = EBox::Config::tmp() . 'stderr';
        my $cmd = 'sudo ' . P3SCAN_BIN . $params .
            " > $outFile " .      " 2> $errFile";
        system ($cmd);

        if ($? != 0 ) {
            my @output;
            if ( -r $outFile) {
                @output = read_file($outFile);
            }

            my @error;
            if ( -r $errFile) {
                @error = read_file($errFile);
            }

            EBox::Sudo::_commandError(P3SCAN_BIN, $?, \@output, \@error);
        }

    }

#   my $daemonCmd = P3SCAN_INITD . ' ' . $action;
#   EBox::debug($daemonCmd);
#   EBox::Sudo::root($daemonCmd);

#  EBox::Service::manage(P3SCAN_SERVICE, $action);
}

sub _confAttr
{
    my ($self, $attr) = @_;

    if (not $self->{configuration}) {
        my $mailfilter = EBox::Global->modInstance('mailfilter');
        $self->{configuration}     = $mailfilter->model('POPProxyConfiguration');
    }

    my $row = $self->{configuration}->row();
    return $row->valueByName($attr);
}


sub isEnabled
{
    my ($self) = @_;
    # FIXME: disabled until fixed
    #return $self->_confAttr('enabled');
    return 0;
}


sub port
{
    return P3SCAN_PORT;
}

# we ignore freshclam running state
sub isRunning
{
    my ($self) = @_;
    system 'pgrep -f ' . P3SCAN_BIN . '  2>&1 > /dev/null';
    return ($? == 0);

    #return EBox::Service::running(P3SCAN_SERVICE);
}

sub stopService
{
    my ($self) = @_;

    if ($self->isRunning()) {
        $self->_daemon('stop');
    }
}


sub antivirus
{
    my ($self) = @_;
    return $self->_confAttr('antivirus');
}

sub antispam
{
    my ($self) = @_;
    return $self->_confAttr('antispam');
}


sub writeConf
{
    my ($self) = @_;

    EBox::Module::Base::writeConfFileNoCheck(P3SCAN_CONF_FILE,
                              "mailfilter/p3scan.conf.mas",
                              [
                               antivirus => $self->antivirus(),
                               antispam  => $self->antispam(),

                               ispspam   => $self->_confAttr('ispspam'),

                               pidFile => $self->pidFile,
                              ]
                             );


    my $mailfilter = EBox::Global->modInstance('mailfilter');
    my $badExtensions = $mailfilter->model('FileExtensionACL')->banned();

    EBox::Module::Base::writeConfFileNoCheck(RENATTACH_CONF_FILE,
                              "mailfilter/renattach.conf.mas",
                              [
                               badExtensions =>  $badExtensions,
                              ]
                             );
}

## firewall method
sub usesPort
{
    my ($self, $protocol, $port, $iface) = @_;

    if ($protocol ne 'tcp') {
        return undef;
    }

    if ($port == $self->port) {
        return 1;
    }

    return undef;
}

sub summary
{
    my ($self, $summary) = @_;

    my $section = new EBox::Dashboard::Section('POPProxy',
                                               __("Transparent POP Proxy"));
    $summary->add($section);

    my $enabled = $self->isEnabled();
    my $status =  new EBox::Dashboard::ModuleStatus(
        module        => 'mailfilter',
        printableName => __('Status'),
        running       => $self->isRunning(),
        enabled       => $self->isEnabled(),
        nobutton      => 1);
    $section->add($status);

    $enabled or return ;

    my $mailfilter = EBox::Global->modInstance('mailfilter');

#     my $antivirus = new EBox::Dashboard::ModuleStatus(
#         module        => 'mailfilter',
#         printableName => __('Antivirus'),
#         enabled       => $self->antivirus(),
#         running       => $mailfilter->antivirus()->isRunning(),
#         nobutton      => 1);
#     $section->add($antivirus);

    my $antispam = new EBox::Dashboard::ModuleStatus(
            module        => 'mailfilter',
            printableName => __('Antispam'),
            enabled       => $self->antispam(),
            running       => $mailfilter->antispam()->isRunning(),
            nobutton      => 1);
    $section->add($antispam);
}

1;
