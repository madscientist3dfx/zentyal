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

# Class: EBox::UsersAndGroups::Slave
#
#    These methods will be called when a user or group is added,
#    modified or deleted. They can be implemented in order to sync
#    that changes to other machines (master provider).
#
package EBox::UsersAndGroups::Slave;

use strict;
use warnings;

use base 'EBox::LdapUserBase';

use EBox::Exceptions::Internal;
use EBox::Exceptions::NotImplemented;
use Error qw(:try);
use File::Temp qw/tempfile/;
use Time::HiRes qw(gettimeofday);
use JSON::XS;
use File::Slurp;
use EBox::UsersAndGroups::LdapObject;
use EBox::UsersAndGroups::Group;
use EBox::UsersAndGroups::User;

# Method: new
#
#   Create a new slave instance, choosen name should
#   be unique between all the slaves
#
sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};

    $self->{name} = delete $opts{name};
    unless (defined($self->{name})) {
        throw EBox::Exceptions::Internal('No name provided');
    }

    bless($self, $class);
    return $self;
}


# Method: sync
#
#   Synchronize an action to the slave.
#   If something fails (for example connectivity) the action
#   will be saved for later, and synchronized by slaves-sync daemon
#
sub sync
{
    my ($self, $signal, $args) = @_;

    try {
        my $method = '_' . $signal;
        $self->$method(@{$args});
    } otherwise {
        # Sync failed, save pending action
        my $name = $self->name();
        EBox::error("Error notifying $name for $signal");
        $self->savePendingSync($signal, $args);
    };
}


# method: savePendingSync
#
#   Save a sync operaction which failed, later slaves-sync should
#   retry it by using syncFromFile
#
sub savePendingSync
{
    my ($self, $signal, $args) = @_;

    my $users = EBox::Global->modInstance('users');
    my $dir = $users->syncJournalDir($self);

    my $time = join('', gettimeofday());
    my ($fh, $filename) = tempfile("$time-$signal-XXXX", DIR => $dir);

    $self->writeActionInfo($fh, $signal, $args);

    $fh->close();
}

sub writeActionInfo
{
    my ($self, $fh, $signal, $args) = @_;

    my @params;
    foreach my $arg (@{$args}) {
        if (ref($arg) =~ /::/) {
            if ($arg->isa('EBox::UsersAndGroups::LdapObject')) {
                my @lines = split(/\n/, $arg->as_ldif());
                $arg = {
                    class => ref($arg),
                    ldif => \@lines,
                };
            }
        }

        push (@params, $arg);
    }

    # JSON encode args
    my $action = {
        signal => $signal,
        args   => \@params,
    };

    print $fh encode_json($action);
}



# method: syncFromFile
#
#   Try to sync a saved action from a previous failed sync
#
sub syncFromFile
{
    my ($self, $file) = @_;

    my $action = $self->readActionInfo($file);

    my $method = '_' . $action->{signal};
    my $args = $action->{args};

    try {
        $self->$method(@{$args});
        unlink ($file);
    } otherwise {
        my $name = $self->name();
        EBox::error("Error notifying $name for $method");
    };
}


sub readActionInfo
{
    my ($self, $file) = @_;

    my $action = decode_json(read_file($file));

    my $signal = $action->{signal};
    my $args = $action->{args};

    my @params;
    foreach my $arg (@{$args}) {
        if (ref($arg) eq 'HASH') {
            # Import LDIF
            my ($fh, $ldif) = tempfile(UNLINK => 1);
            print $fh join("\n", @{$arg->{ldif}});
            $fh->close();

            my $class = $arg->{class};
            $arg = $class->new(ldif => $ldif);
        }
        push (@params, $arg);
    }

    $action->{args} = \@params;

    return $action;
}

sub name
{
    my ($self) = @_;
    return $self->{name};
}


1;
