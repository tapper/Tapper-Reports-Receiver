package Tapper::Reports::Receiver;

use 5.010;
use strict;
use warnings;

our $VERSION = '2.010028';

use parent 'Net::Server::PreFork';
use Log::Log4perl;
use Tapper::Config;
use IO::Scalar;
use File::MimeInfo::Magic;

BEGIN {
        Log::Log4perl::init(Tapper::Config->subconfig->{files}{log4perl_cfg});
}

our $logger = Log::Log4perl->get_logger('tapper.reports.receiver');


use YAML::Syck;
use Data::Dumper;
use Tapper::TAP::Harness;
use Tapper::Model 'model';
use DateTime::Format::Natural;

sub start_new_report {
        my $self = shift;

        $self->{$_} = $self->get_property($_) foreach qw(peeraddr peerport peerhost);
        $self->{report} = model('ReportsDB')->resultset('Report')->new({
                                                                        peeraddr => $self->{peeraddr},
                                                                        peerport => $self->{peerport},
                                                                        peerhost => $self->{peerhost},
                                                                       });
        $self->{report}->insert;
        my $tap = model('ReportsDB')->resultset('Tap')->new({
                                                             tap => '',
                                                             report_id => $self->{report}->id,
                                                            });
        $tap->insert;
}

sub process_request
{
        my $self = shift;

        # Early get report id and print report it back in case
        # connection, because later the connection might just be
        # closed at client side.

        $self->start_new_report;
        print ( "Tapper::Reports::Receiver. Protocol is TAP. Your report id: ". $self->{report}->id. "\n");
        $self->{tap} = '';
        my $timeout = Tapper::Config->subconfig->{times}{receiver_timeout};
        eval {
                local $SIG{ALRM} = sub { die "Timeout" };
                alarm ($timeout);
                while (<STDIN>) {
                        alarm ($timeout);
                        $self->{tap} .= $_ ;
                }
        };
        alarm 0;
        $logger->error('timeout reached for reading TAP') if $@;

        # Don't put more code here - when connection is closed from
        # client side, this point here is never reached.
}

sub tap_mimetype {
        my ($self) = shift;

        my $TAPH      = IO::Scalar->new(\($self->{tap}));
        return mimetype($TAPH);
}

sub tap_is_archive
{
        my ($self) = shift;

        return $self->tap_mimetype =~ m,application/x-(compressed-tar|gzip), ? 1 : 0;
}

sub write_tap_to_db
{
        my ($self) = shift;

        $self->{report}->tap->tap_is_archive(1) if $self->tap_is_archive;
        $self->{report}->tap->tap( $self->{tap} );
        $self->{report}->tap->update;

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
                      report_id  => $self->{report}->id,
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
                      report_id     => $self->{report}->id,
                      arbitrary_id  => $reportgroup_arbitrary,
                      primaryreport => $reportgroup_primary,
                     });
                $reportgroup->insert;
        }

        if ($reportgroup_testrun and $reportgroup_testrun ne 'None') {
                my $reportgroup = model('ReportsDB')->resultset('ReportgroupTestrun')->new
                    ({
                      report_id     => $self->{report}->id,
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
                      report_id  => $self->{report}->id,
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
                $self->{report}->$_( $value ) if defined $value;
        }

        # report information - date fields
        foreach (keys %{$parsed_report->{db_report_date_meta}})
        {
                my $value = $parsed_report->{db_report_date_meta}{$_};
                $self->{report}->$_( DateTime::Format::Natural->new->parse_datetime($value ) ) if defined $value;
        }

        # success statistics
        foreach (keys %{$parsed_report->{stats}})
        {
                my $value = $parsed_report->{stats}{$_};
                $self->{report}->$_( $value ) if defined $value;
        }

        $self->{report}->update;

        $self->create_report_sections($parsed_report);
        $self->create_report_groups($parsed_report);
        $self->create_report_comment($parsed_report);
        $self->create_rss($parsed_report);

}

sub create_rss
{
        my ($self, $parsed_report) = @_;


}

sub _print_report
{
        my ($self, $parsed_report) = @_;

        # TODO: convert to log4perl
        $logger->debug("Report: ", join(", ",
                                        $self->{report}->id,
                                        $self->{report}->successgrade,
                                        $parsed_report->{report_meta}{'suite-name'}."-".$parsed_report->{report_meta}{'suite-version'},
                                       ));
        foreach my $section (@{$parsed_report->{tap_sections}}) {
                $logger->debug($section->{section_name});

                my $section_meta = $section->{db_section_meta};
                foreach my $section_key (keys %$section_meta) {
                        my $value = $section_meta->{$section_key};
                        $logger->debug("        - $section_key: $value");
                }
        }
}

sub post_process_request_hook
{
        my ($self) = shift;

        $self->write_tap_to_db();

        my $harness = Tapper::TAP::Harness->new( tap => $self->{tap}, 
                                                  tap_is_archive => $self->{report}->tap->tap_is_archive );
        $harness->evaluate_report();

        $self->update_parsed_report_in_db( $harness->parsed_report );

        # $self->_print_report( $harness->parsed_report );
}

# Recalculates all DB data out of the TAP report. This may be used if
# something went wrong but the report TAP is available or if things
# have changed how info is extracted from the TAP.
sub refresh_db_report
{
        my ($self) = shift;
        my ($report_id) = @_;

        $self->{report} = model('ReportsDB')->resultset('Report')->find($report_id);

        my $harness = new Tapper::TAP::Harness( tap => $self->{report}->tap );
        $harness->evaluate_report();

        $self->update_parsed_report_in_db( $harness->parsed_report );

        # $self->_print_report( $harness->parsed_report );
}

1;


=head1 NAME

Tapper::Reports::Receiver - Receive test reports


=head1 SYNOPSIS

    use Tapper::Reports::Receiver;
    my $foo = Tapper::Reports::Receiver->new();
    ...

=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: restrictive


=cut

1; # End of Tapper::Reports::Receiver
