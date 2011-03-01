package Tapper::Reports::Receiver::Util;

use 5.010;
use strict;
use warnings;

use Data::Dumper;
use DateTime::Format::Natural;
use File::MimeInfo::Magic;
use IO::Scalar;
use Log::Log4perl;
use Moose;
use YAML::Syck;

use Tapper::Config;
use Tapper::Model 'model';
use Tapper::TAP::Harness;


with 'MooseX::Log::Log4perl';


has report => (is => 'rw',
              );
has tap => (is => 'rw');
            
             

=head2 start_new_report

Create database entries to store the new report.

@param string - remote host name
@param int    - remote port

@return success - report id

=cut

sub start_new_report {
        my ($self, $host, $port) = @_;
        
        $self->report( model('ReportsDB')->resultset('Report')->new({
                                                                     peerport => $port,
                                                                     peerhost => $host,
                                                                    }));
        $self->report->insert;
        my $tap = model('ReportsDB')->resultset('Tap')->new({
                                                             tap => '',
                                                             report_id => $self->report->id,
                                                            });
        $tap->insert;
        return $self->report->id;
}


sub tap_mimetype {
        my ($self) = shift;

        my $TAPH      = IO::Scalar->new(\($self->tap));
        return mimetype($TAPH);
}

sub tap_is_archive
{
        my ($self) = shift;

        return $self->tap_mimetype =~ m,application/x-(compressed-tar|gzip), ? 1 : 0;
}


=head2 write_tap_to_db

Put tap string into database.

@return success - undef
@return error   - die

=cut

sub write_tap_to_db
{
        my ($self) = shift;

        $self->report->tap->tap_is_archive(1) if $self->tap_is_archive;
        $self->report->tap->tap( $self->tap );
        $self->report->tap->update;
        return;
}

sub get_suite {
        my ($self, $suite_name, $suite_type) = @_;

        $suite_name ||= 'unknown';
        $suite_type ||= 'software';

        my $suite = model("ReportsDB")->resultset('Suite')->search({name => $suite_name })->first;
        if (not $suite) {
                $suite = model("ReportsDB")->resultset('Suite')->new({
                                                                      name => $suite_name,
                                                                      type => $suite_type,
                                                                      description => "$suite_name test suite",
                                                                     });
                $suite->insert;
        }
        return $suite;
}

sub create_report_sections
{
        my ($self, $parsed_report) = @_;

        # meta keys
        my $section_nr = 0;
        foreach my $section ( @{$parsed_report->{tap_sections}} ) {
                $section_nr++;
                my $report_section = model('ReportsDB')->resultset('ReportSection')->new
                    ({
                      report_id  => $self->report->id,
                      succession => $section_nr,
                      name       => $section->{section_name},
                     });

                foreach (keys %{$section->{db_section_meta}})
                {
                        my $value = $section->{db_section_meta}{$_};
                        $report_section->$_ ($value) if defined $value;
                }

                $report_section->insert;
        }
}

sub update_reportgroup_testrun_stats
{
        my ($self, $testrun_id) = @_;

        my $reportgroupstats = model('ReportsDB')->resultset('ReportgroupTestrunStats')->find($testrun_id);
        unless ($reportgroupstats and $reportgroupstats->testrun_id) {
                $reportgroupstats = model('ReportsDB')->resultset('ReportgroupTestrunStats')->new({ testrun_id => $testrun_id });
                $reportgroupstats->insert;
        }

        $reportgroupstats->update_failed_passed;
        $reportgroupstats->update;
}

sub create_report_groups
{
        my ($self, $parsed_report) = @_;

        my ($reportgroup_arbitrary,
            $reportgroup_testrun,
            $reportgroup_primary
           ) = (
                $parsed_report->{db_report_reportgroup_meta}{reportgroup_arbitrary},
                $parsed_report->{db_report_reportgroup_meta}{reportgroup_testrun},
                $parsed_report->{db_report_reportgroup_meta}{reportgroup_primary},
               );

        if ($reportgroup_arbitrary and $reportgroup_arbitrary ne 'None') {
                my $reportgroup = model('ReportsDB')->resultset('ReportgroupArbitrary')->new
                    ({
                      report_id     => $self->report->id,
                      arbitrary_id  => $reportgroup_arbitrary,
                      primaryreport => $reportgroup_primary,
                     });
                $reportgroup->insert;
        }

        if ($reportgroup_testrun and $reportgroup_testrun ne 'None') {
                my $reportgroup = model('ReportsDB')->resultset('ReportgroupTestrun')->new
                    ({
                      report_id     => $self->report->id,
                      testrun_id    => $reportgroup_testrun,
                      primaryreport => $reportgroup_primary,
                     });
                $reportgroup->insert;

                $self->update_reportgroup_testrun_stats($reportgroup_testrun);
        }
}

sub create_report_comment
{
        my ($self, $parsed_report) = @_;

        my ($comment) = ( $parsed_report->{db_report_reportcomment_meta}{reportcomment} );
        if ($comment) {
                my $reportcomment = model('ReportsDB')->resultset('ReportComment')->new
                    ({
                      report_id  => $self->report->id,
                      comment    => $comment,
                      succession => 1,
                     });
                $reportcomment->insert;
        }
}

sub update_parsed_report_in_db
{
        my ($self, $parsed_report) = @_;

        no strict 'refs'; ## no critic (ProhibitNoStrict)

        # lookup missing values in db
        $parsed_report->{db_report_meta}{suite_id} = $self->get_suite($parsed_report->{report_meta}{'suite-name'},
                                                                      $parsed_report->{report_meta}{'suite-type'},
                                                                     )->id;

        # report information
        foreach (keys %{$parsed_report->{db_report_meta}})
        {
                my $value = $parsed_report->{db_report_meta}{$_};
                $self->report->$_( $value ) if defined $value;
        }

        # report information - date fields
        foreach (keys %{$parsed_report->{db_report_date_meta}})
        {
                my $value = $parsed_report->{db_report_date_meta}{$_};
                $self->report->$_( DateTime::Format::Natural->new->parse_datetime($value ) ) if defined $value;
        }

        # success statistics
        foreach (keys %{$parsed_report->{stats}})
        {
                my $value = $parsed_report->{stats}{$_};
                $self->report->$_( $value ) if defined $value;
        }

        $self->report->update;

        $self->create_report_sections($parsed_report);
        $self->create_report_groups($parsed_report);
        $self->create_report_comment($parsed_report);

}

=head2 process_request

Process the tap and put it into the database.

@param string - tap

=cut

sub process_request
{
        my ($self, $tap) = @_;

        $self->tap($tap);

        $self->write_tap_to_db();

        my $harness = Tapper::TAP::Harness->new( tap => $self->tap, 
                                                  tap_is_archive => $self->report->tap->tap_is_archive );
        $harness->evaluate_report();

        $self->update_parsed_report_in_db( $harness->parsed_report );

}



1;


=head1 NAME

Tapper::Reports::Receiver - Receive test reports


=head1 SYNOPSIS

    use Tapper::Reports::Receiver;
    my $foo = Tapper::Reports::Receiver->new();
    ...

=head1 AUTHOR

AMD OSRC Tapper Team, C<< <tapper at amd64.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 AMD OSRC Tapper Team, all rights reserved.

This program is released under the following license: freebsd


=cut

1; # End of Tapper::Reports::Receiver
