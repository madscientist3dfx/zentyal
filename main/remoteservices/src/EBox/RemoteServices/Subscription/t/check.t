#!/usr/bin/perl -w

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

# A module to test the <EBox::RemoteServices::Subscription::Check> class

use strict;
use warnings;

use EBox;
use Test::Exception;
use Test::More tests => 3;

BEGIN {
    diag('A unit test for EBox::RemoteServices::Subscription::Check');
    use_ok('EBox::RemoteServices::Subscription::Check')
      or die;
}

EBox::init();

my $checker = new EBox::RemoteServices::Subscription::Check(user => 'foo', password => 'bar');
isa_ok($checker, 'EBox::RemoteServices::Subscription::Check');

diag "Check capabilities for a SB edition";
lives_ok {
    $checker->_performSBChecks();
} 'Capable for SB edition';

1;
