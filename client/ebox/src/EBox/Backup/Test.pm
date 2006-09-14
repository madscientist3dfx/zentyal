# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Backup::Test;

use strict;
use warnings;

use base 'EBox::Test::Class';

use Test::MockObject;
use Test::More;
use Test::Exception;
use EBox::Test qw(checkModuleInstantiation fakeEBoxModule);
use EBox::Gettext;
use File::Slurp qw(read_file write_file);
use EBox::FileSystem qw(makePrivateDir);


use Readonly;
Readonly::Scalar my $GCONF_CANARY_KEY => '/ebox/modules/canaryGConf/canary';
Readonly::Scalar my $CANARY_MODULE_VERSION => 'canary 0.1';

sub testDir
{
  return '/tmp/ebox.backup.test';
}




sub setupDirs : Test(setup)
{
  my ($self) = @_;

  return if !exists $INC{'EBox/Backup.pm'};

  EBox::Config::TestStub::fake( tmp => $self->testDir() );

  my $testDir = $self->testDir();
  system "rm -rf $testDir";

  makePrivateDir($testDir);

  system "rm -rf /tmp/backup";
  ($? == 0) or die $!;
  makePrivateDir('/tmp/backup');
}



sub _useOkTest : Test(1)
{
  use_ok('EBox::Backup');
}




sub setUpCanaryModule
{
  my ($self) = @_;


  fakeEBoxModule(
		 name => 'canaryJail',
		 subs => [
			  setCanary => sub { my ($self, $canary) = @_; $self->{canary} = $canary },
			  canary => sub { my ($self) = @_; return $self->{canary} },
			  setVersion => sub { my ($self, $version) = @_; $self->{version} = $version },
			  version => sub { my ($self) = @_; return $self->{version} },

			 ],
		);
  fakeEBoxModule(
		 name => 'canaryGConf',
		);

}


sub setCanaries
{
  my ($value) = @_;

  my $client = Gnome2::GConf::Client->get_default;
  $client->set_string($GCONF_CANARY_KEY, $value);
  die 'gconf canart not changed' if $client->get_string($GCONF_CANARY_KEY) ne $value;

  my $canaryJail = EBox::Global->modInstance('canaryJail');
  $canaryJail->setCanary($value);
  die 'canary not changed' if $canaryJail->canary() ne $value;
}


sub checkCanaries
{
  my ($expectedValue) = @_;  
  my $value;

  my $client = Gnome2::GConf::Client->get_default;
  $value = $client->get_string($GCONF_CANARY_KEY);
  is $value, $expectedValue, 'Checking GConf canary';

  my $canaryJail = EBox::Global->modInstance('canaryJail');
  $value = $canaryJail->canary();
  is $value, $expectedValue, 'Checking module canary';

  my $version  = $canaryJail->version();
  is $version, $CANARY_MODULE_VERSION, 'Checking if version information was correctly backed';
}


sub checkBackupHelpers
{
  # we check if all the backupHelpers where correctly used
  my @backupHelpers = map { $_->can('backupHelper') ? $_->backupHelper() : ()  }  @{ EBox::Global->modInstances() };
  foreach my $mockBh (@backupHelpers) {
    is $mockBh->call_pos(1), 'version', 'Checking that version was called in the mocked backupHelper';
    is $mockBh->call_pos(2), 'dumpConf', 'Checking that dumpConf was called in the mocked backupHelper';
    is $mockBh->call_pos(3), 'restoreConf', 'Checking that restoreConf was called in the mocked backupHelper';
    is $mockBh->call_pos(4), undef, 'Checking that no more methods upon the backupHelper were called';
  }
}

sub teardownGConfCanary : Test(teardown)
{
  my $client = Gnome2::GConf::Client->get_default;
  $client->unset($GCONF_CANARY_KEY);  
}

sub teardownCanaryModule : Test(teardown)
{
  my ($self) = @_;
  delete $self->{cachedBH}; #delete cached backupHelper

  EBox::Test::setConfig(); 
}


sub backupAndRestoreTest : Test(6)
{
  my ($self) = @_;

  $self->setUpCanaryModule();
  EBox::Test::setEBoxConfigKeys(conf => testDir(), tmp => $self->testDir());

  my $backup = new EBox::Backup();
  my $backupArchive;
 

  setCanaries('beforeBackup');
  lives_ok { $backupArchive = $backup->makeBackup('test backup') } 'makeBackup()';


  setCanaries('afterBackup');
  lives_ok { $backup->restoreBackup($backupArchive) } 'restoreBackup()';

  checkCanaries('beforeBackup');
  

}


sub gconfDumpAndRestoreTest #: Test(3)
{
  my $backup = EBox::Backup->_create();

  EBox::FileSystem::makePrivateDir($backup->dumpDir());

  my $beforeValue = 'beforeDump';
  my $client = Gnome2::GConf::Client->get_default;
  $client->set_string($GCONF_CANARY_KEY, $beforeValue);

  lives_ok { $backup->dumpGConf() } "Dumping GConf";

  $client->set_string($GCONF_CANARY_KEY, 'After dump');

  # do nothing and suppose that a backup has been done...

  lives_ok { $backup->restoreGConf() } 'Restoring GConf';
  is $client->get_string($GCONF_CANARY_KEY), $beforeValue, 'Checking canary GConf entry after restore';


}

1;
