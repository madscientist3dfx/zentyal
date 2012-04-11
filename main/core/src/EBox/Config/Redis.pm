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
use EBox::Util::Semaphore;
use POSIX ':signal_h';
use YAML::XS;
use File::Slurp;
use File::Basename;
use Perl6::Junction qw(any);
use JSON::XS;
use Error qw/:try/;

my $SEM_KEY = 0xEBEB;

my $redis = undef;

# Constants
use constant REDIS_CONF => 'conf/redis.conf';
use constant REDIS_PASS => 'conf/redis.passwd';
use constant CLIENT_CONF => EBox::Config::etc() . 'core.conf';

use constant REDIS_TYPES => qw(string list hash);

# TODO: remove this when stable
my $CACHE_ENABLED = 1;
my $TRANSACTIONS_ENABLED = 1;

my %cache;
my %keys;
my @queue;
my $cacheVersion = 0;
my $trans = 0;
my $sem = undef;

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

    if ($TRANSACTIONS_ENABLED and not $sem) {
        $sem = EBox::Util::Semaphore->init($SEM_KEY);
    }

    return $self;
}

# Method: set_string
#
#   Set key to $value
#
sub set_string
{
    my ($self, $key, $value) = @_;

    $self->begin();

    # Sets the new key
    $self->_redis_call('set', $key, $value);

    $self->commit();
}

# Method: get_string
#
#   Fetch the value stored in key
#
sub get_string
{
    my ($self, $key) = @_;

    return $self->_redis_call('get', $key);
}

# Method: set_int
#
#   Set $key to $value
#
sub set_int
{
    my ($self, $key, $value) = @_;

    $self->set_string($key, $value);
}

# Method: get_int
#
#   Fetch the value stored in $key
#
sub get_int
{
    my ($self, $key) = @_;

    return $self->get_string($key);
}

# Method:  set_bool
#
#   Set $key to $value
#
sub set_bool
{
    my ($self, $key, $value) = @_;

    $self->set_string($key, $value ? 1 : 0);
}

# Method: get_bool
#
#    Fetch the value stored in $key
#
sub get_bool
{
    my ($self, $key) = @_;

    return $self->get_string($key);
}

# Method: set_list
#
#   Set $key to $list. Where $list is an array ref.
#
sub set_list
{
    my ($self, $key, $list) = @_;

    $self->set_string($key, encode_json($list));
}

# Method: list_add
#
#   Push a new element to the end of the list.
#
sub list_add
{
    my ($self, $key, $value) = @_;

    $self->begin();

    my $list = $self->get_list($key);
    push (@{$list}, $value);
    $self->set_list($key, $list);

    $self->commit();
}

# Method: get_list
#
#   Fetch the array ref stored in $key
#
sub get_list
{
    my ($self, $key) = @_;

    my $list = $self->_redis_call('get', $key);
    if ($list) {
        return decode_json($list);
    } else {
        return [];
    }
}

# Method: set_hash
#
#   Set $key to $hash. Where $hash is an array ref.
#
sub set_hash
{
    my ($self, $key, $hash) = @_;

    $self->set_list($hash);
}

# Method: get_hash
#
#   Fetch the hash ref stored in $key
#
sub get_hash
{
    my ($self, $key) = @_;

    my $list = $self->_redis_call('get', $key);
    if ($list) {
        return decode_json($list);
    } else {
        return {};
    }
}

# Method: all_dirs
#
#   Return an array ref contaning all the directories in $key
#
sub all_dirs
{
    my ($self, $key) = @_;

    my $length = length $key;
    my %dir;
    for my $path ($self->_redis_call('keys', "$key/*")) {
        my $index = index($path, '/', $length + 1);
        if ($index > 0) {
            my $directory = substr($path, 0, $index);
            $dir{$directory} = undef;
        }
    }
    return [keys %dir];
}

# Method: all_entries
#
#   Return an array ref contaning all the entries in $key
#
sub all_entries
{
    my ($self, $key) = @_;

    my $length = length $key;
    my @dirs;
    for my $path ($self->_redis_call('keys', "$key/*")) {
        push (@dirs, $path) if (index($path, '/', $length + 1) == -1);
    }
    return \@dirs;
}

# Method: dir_exists
#
#   Returns true if the given directory exists in the loaded configuration.
#
sub dir_exists
{
    my ($self, $dir) = @_;

    my @keys = $self->_redis_call('keys', "${dir}/*");
    return (@keys > 0);
}

# Method: delete_dir
#
#   Delete a directory recursively
#
sub delete_dir
{
    my ($self, $dir) = @_;

    $self->begin();

    if ($self->dir_exists($dir)) {
        my @keys = $self->_redis_call('keys', "$dir/*");
        $self->_redis_call('del', @keys);
    }

    $self->commit();
}

# Method: unset
#
#   Unset a key
#
sub unset
{
    my ($self, $key) = @_;

    $self->begin();

    $self->_redis_call('del', $key);

    $self->commit();
}

# Method: exists
#
#   Check if a given key exists
#
sub exists
{
    my ($self, $key) = @_;

    # FIXME: is this necessary?
    throw EBox::Exceptions::Internal("CALL TO DEPRECATED METHOD EXISTS");

    $self->_redis_call('exists', $key);
}

# Method: get
#
# Generic get to retrieve keys. It will
# automatically check if it's a scalar,
# list, set or hash value unless optional
# type argument is specified.
#
sub get
{
    my ($self, $key, $type) = @_;

# FIXME: is this really used?

    throw EBox::Exceptions::Internal("DEPRECATED CALL TO REDIS GET");
    unless (defined ($type)) {
        $type = $self->_redis_call('type', $key);
    }

    if ($type eq any((REDIS_TYPES))) {
        my $getter = "get_$type";
        return $self->$getter($key);
    } else {
        return undef;
    }
}

# Method: set
#
# Generic method to key values. It will
# automatically check if it's a scalar,
# list or hash value unless the optional
# type argument is specified.
#
sub set
{
    my ($self, $key, $value, $type) = @_;

    unless (defined ($type)) {
        $type = ref ($value);
        if ($type eq 'ARRAY') {
            $type = 'list';
        } elsif ($type eq 'HASH') {
            $type = 'hash';
        } else {
            $type = 'string';
        }
    }

    if ($type eq any((REDIS_TYPES))) {
        my $setter = "set_$type";
        return $self->$setter($key, $value);
    } else {
        return undef;
    }
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

# Method: restore_dir
#
#   Restore orig/$key in $dest
#
sub restore_dir
{
    my ($self, $key, $orig, $dest) = @_;

    $self->begin();

    $self->delete_dir($dest . $key);
    $self->_restore_dir($key, $orig, $dest);

    $self->commit();
}


# Method: export_dir_to_yaml
#
#   Back up a given dir in YAML file
#
# Parameters:
#
#   key         - key for the directory
#   file        - yaml file to write
#
sub export_dir_to_yaml
{
    my ($self, $key, $file) = @_;

    my @keys;
    $self->_backup_dir(
        key => $key,
        destination_type => 'yaml',
        destination => \@keys
    );
    try {
        YAML::XS::DumpFile($file, @keys);
    } otherwise {
        throw EBox::Exceptions::External("Error dumping $key to YAML:$file");
    };
}

sub set_hash_value
{
    my ($self, $key, $field, $value) = @_;

    my $orig = $self->get_hash($key);
    $orig->{$field} = $value;
    $self->set_hash($key, $orig);
}

sub set_hash_values
{
    my ($self, $key, $hash) = @_;

    my $orig = $self->get_hash($key);
    foreach my $elem (keys %{$hash}) {
        $orig->{$elem} = $hash->{$elem};
    }
    $self->set_hash($key, $orig);
}

sub hash_value
{
    my ($self, $key, $field) = @_;

    my $hash = $self->get_hash($key);
    return $hash->{$field};
}

sub hash_delete
{
    my ($self, $key, @fields) = @_;

    my $orig = $self->get_hash($key);
    map { delete $orig->{$_} } @fields;
    $self->set_hash($key, $orig);
}

# Method: import_dir_from_yaml
#
#   Given a YAML file, restore all its keys/values under destination folder
#
# Parameters:
#
#   filename - YAML filename
#   dest - destination folder key
#
sub import_dir_from_yaml
{
    my ($self, $filename, $dest) = @_;

    my @keys;

    try {
        @keys = YAML::XS::LoadFile($filename);
    } otherwise {
        throw EBox::Exceptions::External("Error parsing YAML:$filename");
    };

    $self->begin();

    for my $entry (@keys) {
        my $value = $entry->{value};
        my $key;
        if ($dest) {
            $key = $dest . $entry->{key};
        } else {
            $key = $entry->{key};
        }
        my $type = $entry->{type};
        $self->set($key, $value, $type);
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

    for my $entry (@{$self->all_entries($key)}) {
        my $destKey = $entry;
        if ($destinationType eq 'redis') {
            $destKey = $dest . substr($destKey, length($key));
        }

        my $value = $self->_redis_call('get', $entry);
        if ($destinationType eq 'redis') {
            $self->_redis_call('set', $destKey, $value);
        } else {
                push (@{$args{destination}},
                        {
                            key => $destKey,
                            value => $value
                        }
                     );
            }
    }

    my $destKey = $dest;
    for my $subdir (@{$self->all_dirs($key)}) {
        if ($destinationType eq 'redis') {
            $destKey = $dest . substr($subdir, length($key));
        }
        $self->_backup_dir(
            key => $subdir,
            destination => $destKey,
            destination_type => $destinationType,
        );
    }

    $self->commit();
}

sub _restore_dir
{
    my ($self, $key, $orig, $dest) = @_;

    $self->begin();

    for my $entry (@{$self->all_entries($orig . $key)}) {
        my $destKey = $dest . substr($entry, length($orig));
        my $value = $self->_redis_call('get', $entry);
        $self->_redis_call('set', $destKey, $value);
    }
    for my $subdir (@{$self->all_dirs($orig. $key)}) {
        $self->_restore_dir(substr($subdir, length($orig)), $orig, $dest);
    }

    $self->commit();
}

sub begin
{
    my ($self) = @_;

    return unless $TRANSACTIONS_ENABLED;

    # Do not allow nested transactions
    return if ($trans++);

    $sem->wait();

    my $version = $self->_redis_call_wrapper(0, 'get', 'version');
    defined ($version) or $version = 0;
    if ($version > $cacheVersion) {
        %cache = ();
        %keys = ();
        $cacheVersion = $version;
    }

    return 1;
}

sub commit
{
    my ($self) = @_;

    return unless $TRANSACTIONS_ENABLED;

    $trans--;

    if ($trans == 0) {
        $self->_flush_queue();

        $sem->signal();
    }
}

sub rollback
{
    my ($self) = @_;

    return unless $TRANSACTIONS_ENABLED;

    if ($self->{multi}) {
        $self->_redis_call_wrapper(0, 'discard');
    }

    $trans = 0;

    $sem->signal();
}

sub _flush_queue
{
    my ($self) = @_;

    return unless @queue;

    $self->_redis_call_wrapper(0, 'multi');

    while (@queue) {
        my $cmd = shift (@queue);
        $self->_redis_call_wrapper(0, $cmd->{cmd}, @{$cmd->{args}});
    }

    $self->_redis_call_wrapper(0, 'incr', 'version');

    my $result = $self->_redis_call_wrapper(1, 'exec');
    $cacheVersion = pop @{$result};
}

sub _parent_dir
{
    my ($self, $key, $create) = @_;

    my (@dirs, undef) = split ('/', $key);
    my $name = shift @dirs;
    unless (exists $keys{$name}) {
        if ($create) {
            $keys{$name} = {};
        } else {
            return undef;
        }
    }
    my $dir = $keys{$name};
    while (@dirs) {
        $name = shift @dirs;
        unless (exists $dir->{$name}) {
            if ($create) {
                $dir->{$name} = {};
            } else {
                return undef;
            }
        }
        $dir = $dir->{$name};
    }

    return $dir;
}

# Redis call proxy, tries to get the result from cache and fallbacks
# to _redis_call_wrapper if not present or cache dirty
#
sub _redis_call
{
    my ($self, $command, @args) = @_;

    my $wantarray = wantarray;
    my ($key, @values) = @args;

    unless ($CACHE_ENABLED) {
        my $response = $self->_redis_call_wrapper($wantarray, $command, @args);
        if (ref ($response) eq 'ARRAY') {
            return @{$response};
        } elsif (ref ($response) eq 'HASH') {
            return %{$response};
        } else {
            return $response;
        }
    }

    my $value = $values[0];

    my $write = 1;
    if ($command eq 'set') {
        $cache{$key} = $value;
    } elsif ($command eq 'del') {
        delete $cache{$key};
    } elsif ($command eq 'keys') {
        return $self->_keys_wrapper($key);
    } elsif ($command eq 'get') {
        $write = 0;

        # Get from redis if not in cache
        if (not exists $cache{$key}) {
            $cache{$key} = $self->_redis_call_wrapper($wantarray, $command, @args);
        }

        return $cache{$key};
    }

    if ($write) {
        push (@queue, { cmd => $command, args => \@args });

        # Update keys cache
        my $dir = $self->_parent_dir($key);
        if ($dir) {
            if ($command eq 'del') {
                delete $dir->{$key};
            }  else {
                $dir->{$key} = 1;
            }
        }
    }
}

sub _keys_wrapper
{
    my ($self, $pattern) = @_;

    my $keys = undef;
    my $dir = $self->_parent_dir($pattern);
    if (defined ($dir)) {
        $keys = [ keys %{$dir} ];
    } else {
        $dir = $self->_parent_dir($pattern, 1);
        $keys = $self->_redis_call_wrapper(1, 'keys', $pattern);
        foreach my $name (@{$keys}) {
            unless (exists $cache{$name}) {
                $cache{$name} = {};
            }
            $dir->{$name} = 1;
        }
    }

    return @{$keys};
}

# Wrapper to reconnect to redis in case of detecting a failure when
# issuing a command.
#
sub _redis_call_wrapper
{
    my ($self, $wantarray, $command, @args) = @_;

    # Check process id and respawn redis if has changed (fork)
    if ($self->{pid} ne $$) {
        $self->_respawn();
    }

    my $response;
    my @response;

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
                    $response = \@response;
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
            return $response;
        }
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

    $self->_redis_call_wrapper(0, 'save');
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
