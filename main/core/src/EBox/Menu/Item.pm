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

package EBox::Menu::Item;

use strict;
use warnings;

use base 'EBox::Menu::TextNode';
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $url = delete $opts{url};
    unless (defined($url) and ($url ne '')) {
        throw EBox::Exceptions::MissingArgument('url');
    }
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    $self->{url} = $url;
    return $self;
}

sub add # (item)
{
    my $self = shift;
    throw EBox::Exceptions::Internal(
        "EBox::Menu::Item cannot have children");
}

my $urlsToHide = undef;

sub html
{
    my ($self, $current) = @_;

    unless (defined $urlsToHide) {
        $urlsToHide = {
            map { $_ => 1 } split (/,/, EBox::Config::configkey('menu_urls_to_hide'))
        };
    }

    my $text = $self->{text};
    my $url = $self->{url};
    my $html = '';

    if ($urlsToHide->{$url} or (length($text) == 0)) {
        return $html;
    }

    my $class = "";
    if (defined($current) and ($current eq $url)) {
        $class = "current ";
    }
    if (defined($self->{style})) {
        $class .= $self->{style};
    }
    if($class) {
        $class = "class='$class'";
    }

    my $style = '';
    if ($current) {
       $style = qq/style='display:inline;'/;
    }

    $html .= "<li id='" . $self->{id} . "' $style $class>\n";

    $html .= qq{<a title="$text" href="/$url" class="navc" }
         . qq{ target="_parent">$text</a>\n};

    $html .= "</li>\n";

    return $html;
}

1;
