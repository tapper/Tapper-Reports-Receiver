package Artemis::Reports::Receiver;

use strict;
use warnings;

our $VERSION = '2.010010';

use parent 'Net::Server::Fork';

use Data::Dumper;
use YAML::Syck;
use TAP::Parser;
use TAP::Parser::Aggregator;
use Artemis::TAP::Harness;
use Artemis::Model 'model';
use DateTime::Format::Natural;

sub start_new_report {
        my $self = shift;

        $self->{$_} = $self->get_property($_) foreach qw(peeraddr peerport peerhost);
        print STDERR "peeraddr: ", $self->{peeraddr};
        print STDERR "peerport: ", $self->{peerport};
        print STDERR "peerhost: ", $self->{peerhost};

        $self->{report} = model('ReportsDB')->resultset('Report')->new({
                                                                        tap      => '',
                                                                        peeraddr => $self->{peeraddr},
                                                                        peerport => $self->{peerport},
                                                                        peerhost => $self->{peerhost},
                                                                       });
        $self->{report}->insert;
#         print STDERR "report_id ", $self->{report}->id, " ($$)\n";
}

sub process_request
{
        my $self = shift;

        # Early get report id and print report it back in case
        # connection, because later the connection might just be
        # closed at client side.

        $self->start_new_report;
        print "Artemis::Reports::Receiver. Protocol is TAP. Your report id: ", $self->{report}->id, "\n";

        $self->{tap} = '';
        while (<STDIN>) {
                $self->{tap} .= $_ ;
        }

        # Don't put more code here - when connection is closed from
        # client side, this point here is never reached.
}

sub write_tap_to_db
{
        my ($self) = shift;

        $self->{report}->tap( $self->{tap} );
        $self->{report}->update;
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
                print STDERR "inserted reportgroup_arbitrary: $reportgroup_arbitrary\n";
        }

        if ($reportgroup_testrun and $reportgroup_testrun ne 'None') {
                my $reportgroup = model('ReportsDB')->resultset('ReportgroupTestrun')->new
                    ({
                      report_id     => $self->{report}->id,
                      testrun_id    => $reportgroup_testrun,
                      primaryreport => $reportgroup_primary,
                     });
                $reportgroup->insert;
                print STDERR "inserted reportgroup_testrun: $reportgroup_testrun\n";
        }
}

sub update_parsed_report_in_db
{
        my ($self, $parsed_report) = @_;

        no strict 'refs';

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

}

sub _print_report
{
        my ($self, $parsed_report) = @_;

        say STDERR "Report: ", join(", ",
                                    $self->{report}->id,
                                    $self->{report}->successgrade,
                                    $parsed_report->{report_meta}{'suite-name'}."-".$parsed_report->{report_meta}{'suite-version'},
                                   );
        foreach my $section (@{$parsed_report->{tap_sections}}) {
                say STDERR "        ", $section->{section_name} ;

                my $section_meta = $section->{db_section_meta};
                foreach my $section_name (keys %$section_meta) {
                        my $value = $section_meta->{$section_name};
                        say STDERR "        - $section_name: $value";
                }
        }
}

sub post_process_request_hook
{
        my ($self) = shift;

        $self->write_tap_to_db();

        my $harness = new Artemis::TAP::Harness( tap => $self->{tap} );
        $harness->evaluate_report();

        print STDERR "parsed_report: ", Dumper($harness->parsed_report);
        $self->update_parsed_report_in_db( $harness->parsed_report );

        $self->_print_report( $harness->parsed_report );
}

# Recalculates all DB data out of the TAP report. This may be used if
# something went wrong but the report TAP is available or if things
# have changed how info is extracted from the TAP.
sub refresh_db_report
{
        my ($self) = shift;
        my ($report_id) = @_;

        my $report = model('ReportsDB')->resultset('Report')->find($report_id);

        my $harness = new Artemis::TAP::Harness( tap => $report->tap );
        $harness->evaluate_report();

        print STDERR "parsed_report: ", Dumper($harness->parsed_report);
        $self->update_parsed_report_in_db( $harness->parsed_report );

        $self->_print_report( $harness->parsed_report );
}

1;


=head1 NAME

Artemis::Reports::Receiver - Receive test reports


=head1 SYNOPSIS

    use Artemis::Reports::Receiver;
    my $foo = Artemis::Reports::Receiver->new();
    ...

=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: restrictive


=cut

1; # End of Artemis::Reports::Receiver
