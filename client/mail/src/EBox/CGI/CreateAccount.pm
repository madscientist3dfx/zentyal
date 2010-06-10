# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
# Copyright (C) 2009-2010 eBox Technologies S.L.
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

package EBox::CGI::Mail::CreateAccount;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Mail;
use EBox::Gettext;
use EBox::Exceptions::External;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Mail',
                                      @_);
	$self->{domain} = "ebox-mail";

	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $mail = EBox::Global->modInstance('mail');

	$self->_requireParam('username', __('username'));
	my $username = $self->param('username');
	$self->{redirect} = "UsersAndGroups/User?username=$username";

	$self->keepParam('username');

	$self->_requireParam('vdomain', __('virtual domain'));
	my $vdomain = $self->param('vdomain');
	$self->_requireParam('lhs', __('Mail address'));
	my $lhs = $self->param('lhs');
	my $mdsize = 0;
	if (defined($self->param('mdsize'))) {
		$mdsize = $self->param('mdsize');
	}

	$mail->{musers}->setUserAccount($username, $lhs, $vdomain, $mdsize);
}

1;
