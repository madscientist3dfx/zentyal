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

# Class: EBox::Samba::Model::SambaShares
#
#  This model is used to configure shares different to those which are
#  given by the group share
#
package EBox::Samba::Model::SambaShares;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use Cwd 'abs_path';
use String::ShellQuote;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Boolean;
use EBox::Model::Manager;
use EBox::Exceptions::DataInUse;
use EBox::Sudo;

use Error qw(:try);

use constant DEFAULT_MASK => '0700';
use constant DEFAULT_USER => 'root';
use constant DEFAULT_GROUP => 'root';
use constant GUEST_DEFAULT_MASK => '0777';
use constant GUEST_DEFAULT_USER => 'nobody';
use constant GUEST_DEFAULT_GROUP => 'nogroup';
use constant FILTER_PATH => ('/bin', '/boot', '/dev', '/etc', '/lib', '/root',
                             '/proc', '/run', '/sbin', '/sys', '/var', '/usr');

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the new Samba shares table
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Samba::Model::SambaShares> - the newly created object
#     instance
#
sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);
    bless ($self, $class);

    return $self;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc = (
       new EBox::Types::Text(
                               fieldName     => 'share',
                               printableName => __('Share name'),
                               editable      => 1,
                               unique        => 1,
                              ),
       new EBox::Types::Union(
                               fieldName => 'path',
                               printableName => __('Share path'),
                               subtypes =>
                                [
                                     new EBox::Types::Text(
                                       fieldName     => 'zentyal',
                                       printableName =>
                                            __('Directory under Zentyal'),
                                       editable      => 1,
                                       unique        => 1,
                                                        ),
                                     new EBox::Types::Text(
                                       fieldName     => 'system',
                                       printableName => __('File system path'),
                                       editable      => 1,
                                       unique        => 1,
                                                          ),
                               ],
                               help => _pathHelp($self->parentModule()->SHARES_DIR())),
       new EBox::Types::Text(
                               fieldName     => 'comment',
                               printableName => __('Comment'),
                               editable      => 1,
                              ),
       new EBox::Types::Boolean(
                                   fieldName     => 'guest',
                                   printableName => __('Guest access'),
                                   editable      => 1,
                                   defaultValue  => 0,
                                   help          => __('This share will not require authentication.'),
                                   ),
       new EBox::Types::HasMany(
                               fieldName     => 'access',
                               printableName => __('Access control'),
                               foreignModel => 'SambaSharePermissions',
                               view => '/Samba/View/SambaSharePermissions'
                              ),
       # This hidden field is filled with the group name when the share is configured as
       # a group share through the group addon
       new EBox::Types::Text(
            fieldName => 'groupShare',
            hidden => 1,
            optional => 1,
            ),
      );

    my $dataTable = {
                     tableName          => 'SambaShares',
                     printableTableName => __('Shares'),
                     modelDomain        => 'Samba',
                     defaultActions     => [ 'add', 'del',
                                             'editField', 'changeView' ],
                     tableDescription   => \@tableDesc,
                     menuNamespace      => 'Samba/View/SambaShares',
                     class              => 'dataTable',
                     help               => _sharesHelp(),
                     printableRowName   => __('share'),
                     enableProperty     => 1,
                     defaultEnabledValue => 1,
                     orderedBy          => 'share',
                    };

      return $dataTable;
}

# Method: validateTypedRow
#
#       Override <EBox::Model::DataTable::validateTypedRow> method
#
#   Check if the share path is allowed or not
sub validateTypedRow
{
    my ($self, $action, $parms)  = @_;

    return unless ($action eq 'add' or $action eq 'update');

    if (exists $parms->{'path'}) {
        my $path = $parms->{'path'}->selectedType();
        if ($path eq 'system') {
            # Check if it is an allowed system path
            my $normalized = abs_path($parms->{'path'}->value());
            foreach my $filterPath (FILTER_PATH) {
                if ($normalized =~ /^$filterPath/) {
                    throw EBox::Exceptions::External(
                            __x('Path not allowed. It cannot be under {dir}',
                                dir => $normalized
                               )
                    );
                }
            }
            EBox::Validate::checkAbsoluteFilePath($parms->{'path'}->value(),
                                           __('Samba share absolute path')
                                                );
        } else {
            # Check if it is a valid directory
            my $dir = $parms->{'path'}->value();
            EBox::Validate::checkFilePath($dir,
                                         __('Samba share directory'));
        }
    }
}

# Method: removeRow
#
#   Override <EBox::Model::DataTable::removeRow> method
#
#   Overriden to warn the user if the directory is not empty
#
sub removeRow
{
    my ($self, $id, $force) = @_;

    my $row = $self->row($id);

    if ($force or $row->elementByName('path')->selectedType() eq 'system') {
        return $self->SUPER::removeRow($id, $force);
    }

    my $path =  $self->parentModule()->SHARES_DIR() . '/' .
                $row->valueByName('path');
    unless ( -d $path) {
        return $self->SUPER::removeRow($id, $force);
    }

    opendir (my $dir, $path);
    while(my $entry = readdir ($dir)) {
        next if($entry =~ /^\.\.?$/);
        closedir ($dir);
        throw EBox::Exceptions::DataInUse(
         __('The directory is not empty. Are you sure you want to remove it?'));
    }
    closedir($dir);

    return $self->SUPER::removeRow($id, $force);
}

# Method: deletedRowNotify
#
#   Override <EBox::Model::DataTable::validateRow> method
#
#   Write down shares directories to be removed when saving changes
#
sub deletedRowNotify
{
    my ($self, $row) = @_;

    my $path = $row->elementByName('path');

    # We are only interested in shares created under /home/samba/shares
    return unless ($path->selectedType() eq 'zentyal');

    my $mgr = EBox::Model::Manager->instance();
    my $deletedModel = $mgr->model('SambaDeletedShares');
    $deletedModel->addRow('path' => $path->value());
}

# Method: createDirs
#
#   This method is used to create the necessary directories for those
#   shares which must live under /home/samba/shares
#   We must set here both POSIX ACLs and navite NT ACLs. If we only set
#   POSIX ACLs, a user can change the permissions in the security tab
#   of the share. To avoid it we set also navive NT ACLs and set the
#   owner of the share to 'Domain Admins'.
#
sub createDirs
{
    my ($self) = @_;

    my $sambaModule = $self->parentModule();
    my $ldb = $sambaModule->ldb();

    my $domainSid = $ldb->domainSID();
    my $domainAdminsSid = $domainSid . '-512';
    my $domainUsersSid  = $domainSid . '-513';

    for my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $pathType =  $row->elementByName('path');
        my $guestAccess = $row->valueByName('guest');
        next unless ( $pathType->selectedType() eq 'zentyal');
        my $path = $self->parentModule()->SHARES_DIR() . '/' . $pathType->value();
        my @cmds = ();
        push (@cmds, "mkdir -p '$path'");
        if ($guestAccess) {
           push (@cmds, 'chmod ' . GUEST_DEFAULT_MASK . " '$path'");
           push (@cmds, 'chown ' . GUEST_DEFAULT_USER . ':' . GUEST_DEFAULT_GROUP . " '$path'");
        } else {
           push (@cmds, 'chmod ' . DEFAULT_MASK . " '$path'");
           push (@cmds, 'chown ' . DEFAULT_USER . ':' . DEFAULT_GROUP . " '$path'");
        }
        push (@cmds, "setfacl -b $path"); # Clear POSIX ACLs
        EBox::Sudo::root(@cmds);

        if ($guestAccess) {
            my $ntACL = '';
            $ntACL .= "O:$domainAdminsSid"; # Object's owner
            $ntACL .= "G:$domainUsersSid"; # Object's primary group
            my $aceString = '(A;OICI;0x001301BF;;;S-1-1-0)';
            $ntACL .= "D:$aceString";
            my $cmd = EBox::Samba::SAMBATOOL() . " ntacl set '$ntACL' '$path'";
            try {
                EBox::Sudo::root($cmd);
            } otherwise {
                my $error = shift;
                EBox::error("Coundn't enable NT ACLs for $path: $error");
            };
            next;
        }

        # Build the security descriptor string
        my $ntACL = '';
        $ntACL .= "O:$domainAdminsSid"; # Object's owner
        $ntACL .= "G:$domainUsersSid"; # Object's primary group

        # Build the ACS strings
        my @aceStrings = ();
        push (@aceStrings, '(A;;0x001f01ff;;;SY)'); # SYSTEM account has full access
        push (@aceStrings, "(A;;0x001f01ff;;;$domainAdminsSid)"); # Domain admins have full access

        # Posix ACL
        my @posixACL;
        push (@posixACL, 'u:root:rwx');
        push (@posixACL, 'g::---');
        push (@posixACL, 'g:' . DEFAULT_GROUP . ':---');

        for my $subId (@{$row->subModel('access')->ids()}) {
            my $subRow = $row->subModel('access')->row($subId);
            my $permissions = $subRow->elementByName('permissions');

            my $userType = $subRow->elementByName('user_group');
            my $perm;
            if ($userType->selectedType() eq 'group') {
                $perm = 'g:';
            } elsif ($userType->selectedType() eq 'user') {
                $perm = 'u:';
            }
            my $account = $userType->printableValue();
            my $qobject = shell_quote($account);
            $perm .= $qobject . ':';

            my $aceString = '(A;OICI;';
            if ($permissions->value() eq 'readOnly') {
                $aceString .= '0x001200A9;';
                $perm .= 'rx';
            } elsif ($permissions->value() eq 'readWrite') {
                $aceString .= '0x001301BF;';
                $perm .= 'rwx';
            } elsif ($permissions->value() eq 'administrator') {
                $aceString .= '0x001F01FF;';
                $perm .= 'rwx';
            } else {
                my $type = $permissions->value();
                EBox::error("Unknown share permission type '$type'");
                next;
            }
            push (@posixACL, $perm);

            # Account Sid
            my $object = new EBox::Samba::LdbObject(samAccountName => $account);
            if ($object->exists()) {
                $aceString .= ';;' . $object->sid() . ')';
                push (@aceStrings, $aceString);
            }
        }

        if (@posixACL) {
            try {
                my $cmd = 'setfacl -R -m ' . join(',', @posixACL) . " $path";
                my $defaultCmd = 'setfacl -R -m d:' . join(',d:', @posixACL) ." $path";
                EBox::Sudo::root($cmd);
                EBox::Sudo::root($defaultCmd);

            } otherwise {
                my $error = shift;
                EBox::debug("Couldn't enable POSIX ACLs for $path: $error")
            };
        }
        if (@aceStrings) {
            try {
                my $fullAce = join ('', @aceStrings);
                $ntACL .= "D:$fullAce";
                my $cmd = EBox::Samba::SAMBATOOL() . " ntacl set '$ntACL' '$path'";
                EBox::Sudo::root($cmd);
            } otherwise {
                my $error = shift;
                EBox::error("Coundn't enable NT ACLs for $path: $error");
            };
        }

    }
}

# Private methods
sub _pathHelp
{
    my ($sharesPath) = @_;

    return __x( '{openit}Directory under Zentyal{closeit} will ' .
            'automatically create the share.' .
            "directory in {sharesPath} {br}" .
            '{openit}File system path{closeit} will allow you to share '.
            'an existing directory within your file system',
               sharesPath => $sharesPath,
               openit  => '<i>',
               closeit => '</i>',
               br      => '<br>');

}

sub _sharesHelp
{
    return __('Here you can create shares with more fine-grained permission ' .
              'control. ' .
              'You can use an existing directory or pick a name and let Zentyal ' .
              'create it for you.');
}

# Method: headTile
#
#   Overrides <EBox::Model::DataTable::headTitle>
#
#
sub headTitle
{
    return undef;
}

1;
