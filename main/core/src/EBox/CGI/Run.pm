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

package EBox::CGI::Run;

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::CGI::Base;
use EBox::Model::Manager;
use EBox::CGI::Controller::Composite;
use EBox::CGI::Controller::DataTable;
use EBox::CGI::Controller::Modal;
use EBox::CGI::View::DataTable;
use EBox::CGI::View::Composite;
use CGI;
use File::Slurp;

use Error qw(:try);

use constant URL_ALIAS_FILTER => '/usr/share/zentyal/urls/*.urls';

my %urlAlias;

# Method: classFromUrl
#
#   Map from an URL to the name of the CGI class that needs to be run when
#   the URL is accessed
#
#   It checks the *.urls files to check if the given URL is an alias
#   in order to get the real URL of the CGI
#
# Parameters:
#
#   url - URL to map to a CGI classname
#
# Returns:
#   the name of the CGI class
#
sub classFromUrl
{
    my ($url, $namespace) = @_;

    defined ($url) or exit;

    my $classname = '';
    if ($namespace) {
        $classname = $namespace;
    }
    $classname .= '::CGI::';

    $url = _urlAlias($url);

    $url =~ s/\?.*//g;
    $url =~ s/[\\"']//g;
    $url =~ s/\//::/g;
    $url =~ s/^:://;

    $classname .= $url;

    $classname =~ s/::::/::/g;
    $classname =~ s/::$//;

    if ($classname =~ /::CGI$/) {
        $classname .= '::Dashboard::Index';
    }

    return $classname;
}

# Method: run
#
#    Run the given URL and prints out the returned HTML. This is the eBox
#    Web UI core indeed.
#
# Parameters:
#
#    url - String the URL to get the CGI from, it will transform
#    slashes to double colons
#
#    namespace - String the namespace to prefix the CGI to extract the
#                class name, as explained in <classFromUrl>
#
sub run # (url, namespace)
{
    my ($self, $url, $namespace) = @_;

    my $redis = EBox::Global->modInstance('global')->redis();
    $redis->begin();

    try {
        my $classname = classFromUrl($url, $namespace);

        my $cgi;
        eval "use $classname";
        if ($@) {
            try{
                $cgi = _lookupViewController($classname, $namespace);
            }  catch EBox::Exceptions::DataNotFound with {
                # path not valid
                $cgi = undef;
            };

            if (not $cgi) {
                my $log = EBox::logger;
                $log->error("Unable to import cgi: "
                        . "$classname Eval error: $@");

                my $error_cgi = 'EBox::CGI::SysInfo::PageNotFound';
                eval "use $error_cgi";
                $cgi = new $error_cgi('namespace' => $namespace);
            }
        } else {
            $cgi = new $classname();
        }

        $cgi->run();
        $redis->commit();
    } otherwise {
        $redis->rollback();
    };
}

# Helper functions

sub _urlAlias
{
    my ($url) = @_;

    unless (keys %urlAlias) {
        _readUrlAliases();
    }

    if (exists $urlAlias{$url}) {
        return $urlAlias{$url};
    } else {
        return $url;
    }
}

sub _readUrlAliases
{
    foreach my $file (glob (URL_ALIAS_FILTER)) {
        my @lines = read_file($file);
        foreach my $line (@lines) {
            my ($alias, $url) = split (/\s/, $line);
            $urlAlias{$alias} = $url;
        }
    }
}

sub _posAfterCGI
{
    my ($namespaces) = @_;
    my $i = 0;
    for my $namespace (@{$namespaces}) {
        if ($namespace eq 'CGI') {
            last;
        }
        $i++;
    }
    return $i+1;
}

# Method: lookupModel
#
#   Map from a CGI class name to the appropriate model
#
# Parameters:
#
#   classname - CGI class name to map to a model and an action
#
# Returns:
#   the model and action appropriate for the classname
#
# Exceptions:
#   <EBox::Exceptions::DataNotFound> - thrown if the CGI doesn't use models
#
sub lookupModel
{
    my ($classname) = @_;
    my @namespaces = split ('::', $classname);
    my $pos = _posAfterCGI(\@namespaces);

    my $manager = EBox::Model::Manager->instance();
    my ($namespace, $modelName) = ($namespaces[$pos+1], $namespaces[$pos+2]);
    my ($model, $action) = (undef, undef);

    if ( ($namespace eq 'View') or
            ($namespace eq 'Controller') or
             ($namespace eq 'ModalController')) {

        if ( defined ( $namespaces[$pos+3] ) ) {
            # Set as model name, the context name
            $modelName = '/' . lc ( $namespaces[$pos] ) . '/' . $modelName . '/' . $namespaces[$pos+3];
        } else {
            $modelName = '/' . lc ( $namespaces[$pos] ) . "/$modelName";
        }
        try {
            $model = $manager->model($modelName);
            if ( @namespaces >= $pos+4 ) {
                $action = splice ( @namespaces, $pos+4, 1 );
            }
        } catch EBox::Exceptions::DataNotFound with {
            $action = $namespaces[$pos+3];
            # Remove the previous thought index
            $modelName =~ s:/.*?$::g;
            if (($modelName) ne '') {
                $model = $manager->model($modelName);
            } else {
                throw EBox::Exceptions::DataNotFound(q{model's name});
            }
        };
    } elsif ( $namespace eq 'Composite' ) {
        if ( defined ( $namespaces[$pos+3] )) {
            # It may be the index or the action
            # Compose the composite context name
            my $contextName = '/' . lc ( $namespaces[$pos] ) . '/' . $modelName . '/' . $namespaces[$pos+3];
            try {
                $model = $manager->composite($contextName);
                $action = $namespaces[$pos+4];
            } catch EBox::Exceptions::DataNotFound with {
                $action = $namespaces[$pos+3];
            };
        }
        unless ( defined ( $model)) {
            my $contextName = '/' . lc ( $namespaces[$pos] ) . "/$modelName";
            $model = $manager->composite($contextName);
        }
    }
    return ($model, $action);
}

# Method:: _lookupViewController
#
#       Check if a classname must be mapped to a View or Controller
#       cgi class from a model or a composite
#
sub _lookupViewController
{
        my ($classname, $cginamespace) = @_;

        # URL to map:
        # url => 'EBox::CGI::<moduleName>::' menuNamespaceBranch
        # menuNamespaceBranch => 'View' model | 'Controller' model index | 'Composite' model index action
        # model => '::<modelName>'
        # index => '::<index>' | epsilon
        # action => '::<actionName>' | epsilon

        my ($cgi, $menuNamespace) = (undef, undef);

        my ($model, $action) = lookupModel($classname);

        if($model) {
            my @namespaces = split ( '::', $classname);
            my $pos = _posAfterCGI(\@namespaces);

            my ($namespace, $modelName) = ($namespaces[$pos+1], $namespaces[$pos+2]);

            $menuNamespace = $model->menuNamespace();
            if ( $namespace eq 'View' ) {
                    $cgi = EBox::CGI::View::DataTable->new(
                        'tableModel' => $model,
                        'namespace' => $cginamespace);
            } elsif ( $namespace eq 'Controller' ) {
                    $cgi = EBox::CGI::Controller::DataTable->new(
                        'tableModel' => $model,
                        'namespace' => $cginamespace);
           } elsif ( $namespace eq 'ModalController' ) {
                    $cgi = EBox::CGI::Controller::Modal->new(
                        'tableModel' => $model,
                        'namespace' => $cginamespace);
            } elsif ( $namespace eq 'Composite' ) {
                # Check if the action is defined URL: Composite/<compName>/<action>
                if ( defined ( $action )) {
                    $cgi = new EBox::CGI::Controller::Composite(
                        composite => $model,
                        action    => $action,
                        'namespace' => $cginamespace
                                                               );
                } else {
                    $cgi = new EBox::CGI::View::Composite(
                        composite => $model,
                        'namespace' => $cginamespace
                                                         );
                }
            }
            if (defined($cgi) and defined($menuNamespace)) {
                    $cgi->setMenuNamespace($menuNamespace);
            }
        }
        return $cgi;
}

1;
