# Copyright (C) 2010-2012 eBox Technologies S.L.
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

package EBox::Config::Redis;

use 5.010001;
use strict;
use warnings;

use Redis;
use EBox::Config;
use EBox::Service;
use EBox::Module::Base;
use EBox::Util::SHMLock;
use File::Slurp;
use File::Basename;
use Perl6::Junction qw(any);
use JSON::XS;
use Error qw/:try/;

my $redis = undef;

# Constants
use constant REDIS_CONF => 'conf/redis.conf';
use constant REDIS_PASS => 'conf/redis.passwd';
use constant CLIENT_CONF => EBox::Config::etc() . 'core.conf';

my %cache;
my %modified;
my %deleted;
my $cacheVersion = 0;
my $trans = 0;
my $lock = undef;

# Constructor: new
#
sub new
{
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    # Launch daemon if it does not exists
    unless (defined $redis) {
        $self->_initRedis;
        $self->_respawn;
    }
    $self->{redis} = $redis;
    $self->{pid} = $$;
    $self->{json_pretty} = JSON::XS->new->pretty;

    unless ($lock) {
        $lock = EBox::Util::SHMLock->init('redis');
    }

    return $self;
}

# Method: set
#
#   Set a key with a scalar value or a reference
#
sub set
{
    my ($self, $key, $value) = @_;

    $self->begin();

    $cache{$key} = $value;
    $modified{$key} = 1;
    delete $deleted{$key};

    $self->commit();
}

# Method: get
#
#   Set the value of a key, or the given defaultValue if not exists
#
sub get
{
    my ($self, $key, $defaultValue) = @_;

    # Get from redis if not in cache
    unless (exists $cache{$key}) {
        my $value = $self->_redis_call('get', $key);
        if (defined ($value)) {
            # XXX: this can be problematic if we store a string
            # starting with '[' or '{', but decode_json fails to decode
            # regular strings some times, even with allow_nonref
            # An alternative could be to try always the decode
            # ignoring the exception
            my $firstChar = substr ($value, 0, 1);
            if (($firstChar eq '[') or ($firstChar eq '{')) {
                $value = decode_json($value);
            }
        } else {
            $value = $defaultValue;
        }
        $cache{$key} = $value;
    }

    return $cache{$key};
}


# Method: delete_dir
#
#   Delete a directory recursively
#
sub delete_dir
{
    my ($self, $dir) = @_;

    $self->begin();

    my @keys = $self->_keys("$dir/*");
    $self->unset(@keys);

    $self->commit();
}

# Method: unset
#
#   Unset a key
#
sub unset
{
    my ($self, @keys) = @_;

    $self->begin();

    foreach my $key (@keys) {
        delete $cache{$key};
        $deleted{$key} = 1;
        delete $modified{$key};
    }

    $self->commit();
}

# Method: backup_dir
#
#   Back up a given dir $key in $dest
#
sub backup_dir
{
    my ($self, $key, $dest) = @_;

    $self->begin();

    $self->delete_dir($dest);
    $self->_backup_dir(
        key => $key,
        destination_type => 'redis',
        destination => $dest
    );

    $self->commit();
}

# Method: export_dir_to_file
#
#   Back up a given dir in "key: value" format
#
# Parameters:
#
#   key         - key for the directory
#   file        - file to write
#
sub export_dir_to_file
{
    my ($self, $key, $file) = @_;

    my @keys;
    $self->_backup_dir(
        key => $key,
        destination_type => 'file',
        destination => \@keys
    );
    my @lines = sort (map { "$_->{key}: $_->{value}\n" } @keys);
    try {
        write_file($file, @lines);
    } otherwise {
        throw EBox::Exceptions::External("Error dumping $key to $file");
    };
}

sub _keys
{
    my ($self, $pattern) = @_;

    my @keys = $self->_redis_call('keys', $pattern);
    foreach my $name (keys %cache) {
        if ($name =~ /^$pattern/) {
            push (@keys, $name);
        }
    }

    return @keys;
}

# Method: import_dir_from_file
#
#   Given a "key: value" file, restore them under destination folder
#
# Parameters:
#
#   filename - filename with the dump
#   dest - destination folder key
#
sub import_dir_from_file
{
    my ($self, $filename, $dest) = @_;

    my @lines;

    try {
        @lines = split ("\n\n", read_file($filename));
    } otherwise {
        throw EBox::Exceptions::External("Error parsing YAML:$filename");
    };

    $self->begin();
    foreach my $line (@lines) {
        my ($key, $value) = $line =~ /^(.+?): (.*)$/s;

        if ($dest) {
            $key = $dest . '/' .  $key;
        }
        # XXX: this can be problematic if we store a string
        # starting with '[' or '{', but decode_json fails to decode
        # regular strings some times, even with allow_nonref
        # An alternative could be to try always the decode
        # ignoring the exception
        my $firstChar = substr ($value, 0, 1);
        if (($firstChar eq '[') or ($firstChar eq '{')) {
            $value = $self->{json_pretty}->decode($value);
        }
        $self->set($key, $value);
    }

    $self->commit();
}

sub _backup_dir
{
    my ($self, %args) = @_;

    $self->begin();

    my $key = $args{key};
    my $destinationType = $args{destination_type};
    my $dest = $args{destination};

    my @keys = $self->_keys($key ? "$key/*" : '*');

    for my $entry (@keys) {
        my $destKey = $entry;

        my $value = $self->get($entry);
        if ($destinationType eq 'redis') {
            $destKey =~ s/^$key/$dest/;
            $self->set($destKey, $value);
        } else {
            if (ref $value) {
                $value = $self->{json_pretty}->encode($value);
            } else {
                $value .= "\n";
            }
            push (@{$args{destination}},
                    {
                    key => $destKey,
                    value => $value
                    }
                 );
        }
    }

    $self->commit();
}

sub begin
{
    my ($self) = @_;

    # Do not allow nested transactions
    return if ($trans++);

    $lock->lock();

    my $version = $self->_redis_call('get', 'version');
    defined ($version) or $version = 0;
    if ($version > $cacheVersion) {
        %cache = ();
        $cacheVersion = $version;
    }

    return 1;
}

sub commit
{
    my ($self) = @_;

    $trans--;

    if ($trans == 0) {
        $self->_sync();

        $lock->unlock();
    }
}

sub rollback
{
    my ($self) = @_;

    if ($self->{multi}) {
        $self->_redis_call('discard');
    }

    $trans = 0;

    $lock->unlock();
}

sub _sync
{
    my ($self) = @_;

    return unless (%modified or %deleted);

    $self->_redis_call('multi');

    foreach my $key (keys %modified) {
        my $value = $cache{$key};
        if (ref $value) {
            $value = encode_json($value);
        }
        $self->_redis_call('set', $key, $value);
    }
    %modified = ();

    if (%deleted) {
        $self->_redis_call('del', keys %deleted);
        %deleted = ();
    }

    $self->_redis_call('incr', 'version');

    my @result = $self->_redis_call('exec');
    $cacheVersion = pop @result;
}

# Wrapper to reconnect to redis in case of detecting a failure when
# issuing a command.
#
sub _redis_call
{
    my ($self, $command, @args) = @_;

    # Check process id and respawn redis if has changed (fork)
    if ($self->{pid} ne $$) {
        $self->_respawn();
    }

    my $response;
    my @response;
    my $wantarray = wantarray;

    my $tries = 5;
    for my $i (1 .. $tries) {
        our $failure = 1;
        our $ret;
        {
            local $SIG{PIPE};
            $SIG{PIPE} = sub {
                # EBox::warn("$$ Reconnecting to redis server after SIGPIPE");
                $failure = 1; };
            eval {
                $self->{redis}->__send_command($command, @args);
                if ($wantarray) {
                    @response = $self->{redis}->__read_response();
                    map { utf8::encode($_) if defined ($_) } @response;
                } else {
                    $response = $self->{redis}->__read_response();
                    utf8::encode($response) if defined ($response);
                }
                $failure = 0;
            };
            $ret = $@;
            if ($ret or $failure) {
                # EBox::warn("$$ - $ret");
                sleep(1);
                # Disconnected, try to reconnect
                eval {
                    $self->_initRedis();
                    $self->_respawn();
                    $failure = 1;
                };
                if ($@) {
                    # EBox::warn("$$ -- $@");
                    sleep(1);
                    $failure = 1;
                }
            }
        }

        if ($failure) {
            if ( $i < $tries) {
                warn "Reconnecting to redis server ($i try)...";
            } else {
                my $conProblem = 1;
                if ($ret) {
                    $conProblem = $ret =~ m/closed connection/;
                }

                if ($conProblem) {
                    throw EBox::Exceptions::Internal('Cannot connect to redis server');
                } else {
                    my $error = "Redis command '$command @args' failed: $ret";
                    throw EBox::Exceptions::Internal($error);
                }
            }
        } else {
            last;
        }
    }

    if ($wantarray) {
        return @response;
    } else {
        return $response;
    }
}

# Reconnect to redis server
sub _respawn
{
    my ($self) = @_;

    # try {
    #     $self->{redis}->quit();
    # } otherwise { ; };
    $self->{redis} = undef;
    $redis = undef;

    my $user = $self->_user();
    my $home = $self->_home();
    my $filepasswd = $self->_passwd();

    $redis = Redis->new(sock => "$home/redis.$user.sock");
    $redis->auth($filepasswd);
    $self->{redis} = $redis;
    $self->{pid} = $$;

    # EBox::info("$$ Respawning the redis connection");
}


# Initialize redis daemon if it's not running
sub _initRedis
{
    my ($self) = @_;

    # User corner redis server is managed by service
    return if ( $self->_user eq 'ebox-usercorner' );

    unless (EBox::Service::running('ebox.redis')) {
        EBox::info('Starting redis server');

        # Write redis daemon conf file
        $self->writeConfigFile();

        # Launch daemon, added sleep to avoid first connection problems
        EBox::Sudo::silentRoot('start ebox.redis && sleep 1');
    }
}


# Method: writeConfigFile
#
#   Write redis daemon config file
#
sub writeConfigFile
{
    my ($self, $user) = @_;

    defined($user) or $user = EBox::Config::user();

    my $home = $self->_home($user);

    my $confFile = $home . REDIS_CONF;
    my $pass = $self->_passwd($home);
    my $uid = getpwnam($user);
    my $dir = $user;
    $dir =~ s/ebox/zentyal/;
    my $port = $self->_port($user);

    my @params = ();
    push (@params, user => $user);
    push (@params, home => $home);
    push (@params, dir => $dir);
    push (@params, port => $port);
    push (@params, passwd => $pass);
    EBox::Module::Base::writeConfFileNoCheck($confFile,
            'core/redis.conf.mas',
            \@params, {mode => '0600', uid => $uid});
}

# Stop redis server, sync changes to disk before
sub stopRedis
{
    my ($self) = @_;

    # User corner redis server is managed by service
    return if ($self->_user eq 'ebox-usercorner');

    $self->_redis_call('save');
    EBox::Service::manage('ebox.redis', 'stop');
}


# Returns redis server password
sub _passwd
{
    my ($self, $home) = @_;
    defined($home) or $home = $self->_home();

    return read_file($home . REDIS_PASS) or
        throw EBox::Exceptions::External('Could not open passwd file');
}


# Returns redis server port
sub _port
{
    my ($self, $user) = @_;
    defined($user) or $user = $self->_user();

    if ($user eq 'ebox-usercorner') {
        return EBox::Config::configkey('redis_port_usercorner');
    } else {
        return EBox::Config::configkeyFromFile('redis_port', CLIENT_CONF);
    }

    # Unknown user
    return undef;
}


sub _home
{
    my ($self, $user) = @_;
    defined($user) or $user = $self->_user();

    my ($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam($user);
    return $dir;
}


# Returns current user name
sub _user
{
    my @userdata = getpwuid(POSIX::getuid());
    return $userdata[0];
}

1;
