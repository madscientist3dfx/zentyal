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

# Class: EBox::SysInfo::Model::DateTime
#
#   This model is used to configure the system date time
#

package EBox::SysInfo::Model::DateTime;

use strict;
use warnings;

use Error qw(:try);

use EBox::Gettext;
use EBox::Types::Date;
use EBox::Types::Time;
use EBox::Types::Action;

use base 'EBox::Model::DataForm';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Date( fieldName => 'date',
                                            editable  => \&_enabled),

                     new EBox::Types::Time( fieldName => 'time',
                                            editable  => \&_enabled,
                                            help      => __('A change in the date or time will cause all Zentyal services to be restarted.')));

    my $customActions = [
        new EBox::Types::Action( name => 'changeDateTime',
                                 printableValue => __('Change'),
                                 model => $self,
                                 handler => \&_doChangeDateTime,
                                 enabled => \&_enabled,
                                 message => __('The date and time was changed successfully.'))];

    my $dataTable =
    {
        'tableName' => 'DateTime',
        'printableTableName' => __('Date and time'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [],
        'customActions' => $customActions,
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to
#   show a message if changing the date and time is not allowed
#
sub viewCustomizer
{
    my ($self) = @_;

    my $custom = $self->SUPER::viewCustomizer();
    unless (_enabled()) {
        $self->setMessage(__('As the NTP synchronization with external servers is enabled, you cannot change the date or time.'));
    }

    return $custom;
}

# Method: row
#
#   Override <EBox::Model::DataForm::row> to build and return a
#   row dependening on the current date and time
#
sub row
{
    my ($self) = @_;

    my $date = `date '+%d/%m/%Y'`;
    my $time = `date '+%H:%M:%S'`;

    chomp $date;
    chomp $time;

    my $row = $self->_setValueRow(
            date => $date,
            time => $time,
        );

    $row->setId('dummy');


    return $row;
}

# Method: _doChangeDateTime
#
#   This is the custom action handler
#
sub _doChangeDateTime
{
    my ($self, $action, $id, %params) = @_;

    my $day    = $params{'date_day'};
    my $month  = $params{'date_month'};
    my $year   = $params{'date_year'};
    my $hour   = $params{'time_hour'};
    my $minute = $params{'time_min'};
    my $second = $params{'time_sec'};

    # Date time
    $self->_setNewDate($day, $month, $year, $hour, $minute, $second);
    my $dateStr = "$year/$month/$day $hour:$minute:$second";

    my $audit = EBox::Global->modInstance('audit');
    $audit->logAction('System', 'General', 'changeDateTime', $dateStr);

    $self->setMessage($action->message(), 'note');
    $self->{customActions} = {};
}

# Method: _setNewDate
#
#   Sets the system date and time
#
sub _setNewDate
{
    my ($self, $day, $month, $year, $hour, $minute, $second) = @_;

    my $newdate = "$year-$month-$day $hour:$minute:$second";
    my $command = "/bin/date --set \"$newdate\"";
    EBox::Sudo::root($command);

    $self->parentModule()->_restartAllServices();
}

# Method: _enabled
#
#   Returns 1 if changing the date and time is allowed, 0 otherwise
#
sub _enabled
{
    my $ntp = EBox::Global->modInstance('ntp');
    my $ntpsync = (defined ($ntp) and ($ntp->isEnabled()) and ($ntp->synchronized()));
    if ($ntpsync) {
        return 0;
    } else {
        return 1;
    }
}

1;
