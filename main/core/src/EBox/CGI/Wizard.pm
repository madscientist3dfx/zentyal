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
use strict;
use warnings;

package EBox::CGI::Wizard;
use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Initial configuration wizard'),
            'template' => 'wizard/wizard.mas',
            @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;

    my @array = ();

    my $global = EBox::Global->getInstance();
    my $image = $global->theme()->{'image_title'};
    push (@array, image_title => $image);

    my @pages;
    if ($self->param('page')) {
        @pages = ( $self->param('page') );
    } else {
        @pages = @{ $self->_modulesWizardPages() };
    }

    if (not @pages) {
        my $global = EBox::Global->getInstance();
        if ($global->unsaved()) {
            $self->{redirect} = '/SaveChanges?firstTime=1&noPopup=1&save=1';
        } else {
            $self->{redirect} = '/Wizard/FirstFinish';
        }
        return;
    }


    push(@array, 'pages' => \@pages);
    push(@array, 'first' => EBox::Global->first());
    $self->{params} = \@array;
}


# Method: _modulesWizardPages
#
#   Returns an array ref with installed modules wizard pages
sub _modulesWizardPages
{
    my $global = EBox::Global->getInstance();
    my @pages = ();

    my @modules = @{$global->modInstancesOfType('EBox::Module::Service')};

    foreach my $module ( @modules ) {
#         # DDD
#         if ($module->name() eq 'mail') {
#             push (@pages, @{$module->wizardPages()});
#             next;
#         }
#         if ($module->name() eq 'users') {
#             push (@pages, @{$module->wizardPages()});
#             next;
#         }

        if ($module->firstInstall()) {
            push (@pages, @{$module->wizardPages()});
        }
    }

    # Sort and get pages
    my @sortedPages = sort { $a->{order} <=> $b->{order} } @pages;
    @sortedPages = map { $_->{page} } @sortedPages;

    return \@sortedPages;
}

sub _menu
{
    my ($self) = @_;

    if (EBox::Global->first() and EBox::Global->modExists('software')) {
        my $software = EBox::Global->modInstance('software');
        $software->firstTimeMenu(3);
    } else {
        $self->SUPER::_menu(@_);
    }
}

sub _top
{
    my ($self)= @_;
    $self->_topNoAction();
}



1;
