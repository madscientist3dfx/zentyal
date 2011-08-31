# Copyright (C) 2008-2011 eBox Technologies S.L.
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

package EBox::Gettext;

use Locale::gettext;
use EBox::Config;

BEGIN {
    use Exporter ();
    our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

    @ISA = qw(Exporter);
    @EXPORT = qw{ __ __n __x __d __dx __s __sx __p __px settextdomain gettextdomain langs };
    %EXPORT_TAGS = ( DEFAULT => \@EXPORT );
    @EXPORT_OK = qw();
    $VERSION = EBox::Config::version;
}

my $cur_domain = 'zentyal';
my $old_domain;

use constant SUBS_DOMAIN => 'zentyal-subscription';
use constant PROF_DOMAIN => 'zentyal-prof';

# Method: settextdomain
#
#   Sets the curent message domain
#
# Parameters:
#
#       domain - The domain name
#
sub settextdomain # (domain)
{
    my $domain = shift;
    textdomain($domain);
    bindtextdomain($domain, EBox::Config::locale());
    my $old_domain = $cur_domain;
    $cur_domain = $domain;
    return $old_domain;
}

# Method: gettextdomain
#
#   Gathers  the curent message domain
#
# Returns:
#
#      The current message domain
#
sub gettextdomain
{
    return $cur_domain;
}

sub __ # (text)
{
    my ($msgid) = @_;

    # FIXME: Probably there is a better way to do this
    # and avoid setting the domain every time, so this is a
    # temporary solution
    my $string = __d($msgid, 'zentyal');
    $string =~ s/\'/\&#39\;/g;
    $string =~ s/\"/\&#34\;/g;
    return $string;
}

sub __n # (text)
{
    my $string = shift;
    my ($p, $a, $c) = caller;
    return $string;
}

sub __x # (text, %variables)
{
    my ($msgid, %vars) = @_;
    #FIXME: my $string = gettext($msgid);
    my $string = __d($msgid, 'zentyal');
    return __expand($string, %vars);
}

sub __d # (text,domain)
{
    my ($string,$domain) = @_;
    bindtextdomain($domain, EBox::Config::locale());
    textdomain($domain);
    $string = gettext($string);
    textdomain($cur_domain);
    return $string;
}

sub __dx # (text,domain, %variables)
{
    my ($string,$domain, %vars) = @_;
    bindtextdomain($domain, EBox::Config::locale());
    textdomain($domain);
    $string = gettext($string);
    textdomain($cur_domain);
    return __expand($string, %vars);
}

sub __s # (text)
{
    my ($text) = @_;
    return __d($text, SUBS_DOMAIN);

}

sub __sx # (text, %variables)
{
    my ($text, %vars) = @_;

    return __dx($text, SUBS_DOMAIN, %vars);
}

sub __p # (text)
{
    my ($text) = @_;
    return __d($text, PROF_DOMAIN);

}

sub __px # (text, %variables)
{
    my ($text, %vars) = @_;

    return __dx($text, PROF_DOMAIN, %vars);
}

sub __expand # (translation, %arguments)
{
    my ($translation, %args) = @_;

    my $re = join '|', map { quotemeta $_ } keys %args;
    $translation =~ s/\{($re)\}/defined $args{$1} ? $args{$1} : "{$1}"/ge;
    return $translation;
}

my $langs = undef;

# Method:  langname
#
#       Gathers the current set language
#
# Returns:
#
#   the current domain language
#
sub langname # (locale)
{
    my ($locale) = @_;

    return langs()->{$locale};
}

# Method: langs
#
#   gathers the available languages
#
# Returns:
#
#   hash reference -  containing the available languages. Each key
#   represents a *locale* and its value contains the associated
#   language
#
sub langs
{
    unless (defined $langs) {
        $langs = {};
        $langs->{'an_ES.UTF-8'} = 'Aragonés';
        $langs->{'bn_BD.UTF-8'} = 'Bengali';
        $langs->{'bg_BG.UTF-8'} = 'Български';
        $langs->{'es_ES.UTF-8'} = 'Español';
        $langs->{'et_EE.UTF-8'} = 'Eesti';
        $langs->{'ca_ES.UTF-8'} = 'Català';
        $langs->{'cs_CZ.UTF-8'} = 'Czech';
        $langs->{'da_DK.UTF-8'} = 'Dansk';
        $langs->{'de_DE.UTF-8'} = 'Deutsch';
        $langs->{'el_GR.UTF-8'} = 'ελληνικά';
        if (EBox::Config::configkey('english_locale')) {
            $langs->{'en_US.UTF-8'} = 'English';
        } else {
            $langs->{'C'} = 'English';
        }
        $langs->{'eu_ES.UTF-8'} = 'Euskara';
        $langs->{'fa_IR.UTF-8'} = 'فارسی';
        $langs->{'fr_FR.UTF-8'} = 'Français';
        $langs->{'gl_ES.UTF-8'} = 'Galego';
        $langs->{'hu_HU.UTF-8'} = 'Magyar';
        $langs->{'it_IT.UTF-8'} = 'Italiano';
        $langs->{'ja_JP.UTF-8'} = '日本語';
        $langs->{'lt_LT.UTF-8'} = 'Lietuvių';
        $langs->{'nb_NO.UTF-8'} = 'Norsk (bokmål)';
        $langs->{'nl_BE.UTF-8'} = 'Nederlands';
        $langs->{'pl_PL.UTF-8'} = 'Polski';
        $langs->{'pt_BR.UTF-8'} = 'Português do Brasil';
        $langs->{'pt_PT.UTF-8'} = 'Português';
        $langs->{'ro_RO.UTF-8'} = 'Română';
        $langs->{'ru_RU.UTF-8'} = 'Русский';
        $langs->{'sv_SE.UTF-8'} = 'Svenska';
        $langs->{'th_TH.UTF-8'} = 'ภาษาไทย';
        $langs->{'tr_TR.UTF-8'} = 'Türkçe';
        $langs->{'uk_UA.UTF-8'} = 'украї́нська';
        $langs->{'zh_CN.UTF-8'} = '汉字';
        $langs->{'zh_TW.UTF-8'} = '繁體中文';
    }

    return $langs;
}

1;
