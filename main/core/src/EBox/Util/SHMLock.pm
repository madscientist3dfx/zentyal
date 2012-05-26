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

package EBox::Util::SHMLock;

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use Fcntl qw(:flock);

# TODO: remove logging when stable

sub init
{
    my ($class, $name) = @_;

    #EBox::debug("Init lock $name (pid: $$)");

    my $self = {};
    bless $self, $class;

    $self->{name} = $name;

    my $path = EBox::Config::shm();
    my $file = "$path/$name.lock";
    $self->{file} = $file;

    unless (-d $path) {
        system ("mkdir -p $path");
    }
    unless (-f $file) {
        open(LOCKFILE, ">$file") or
            throw EBox::Exceptions::Internal("Cannot create lockfile: $file");
        close(LOCKFILE);
    }

    return $self;
}

sub unlock
{
    my ($self) = @_;

    my $file = $self->{file};

    #EBox::debug("Unlocking $self->{name} (pid: $$)");

    open(LOCKFILE, ">$file") or
        throw EBox::Exceptions::Internal("Cannot open lockfile to unlock: $file");
    flock(LOCKFILE, LOCK_UN);
    close(LOCKFILE);
}

sub lock
{
    my ($self) = @_;

    my $file = $self->{file};

    #EBox::debug("Locking $self->{name} (pid: $$)");

    open(LOCKFILE, ">$file") or
        throw EBox::Exceptions::Internal("Cannot open lockfile to lock: $file");
    flock(LOCKFILE, LOCK_EX) or
        throw EBox::Exceptions::Lock($self->{name});
}

1;
