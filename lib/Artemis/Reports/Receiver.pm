package Artemis::Reports::Receiver;

use strict;
use warnings;

our $VERSION = '2.01';

use parent 'Net::Server::PreForkSimple';

use Data::Dumper;
use YAML::Syck;
use TAP::Parser;
use TAP::Parser::Aggregator;
use Artemis::TAP::Harness;
use Artemis::Model 'model';

sub start_new_report {
        my $self = shift;

        $self->{report} = model('ReportsDB')->resultset('Report')->new({ tap => '' });
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
        $suite_type ||= 'unknown';

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

# parse the TAP, might be already processed and augmented TAP from "prove"


sub update_parsed_report_in_db
{
        my ($self, $parsed_report) = shift;

        # lookup missing values in db
        $parsed_report->{db_meta}{suite_id} = $self->get_suite($parsed_report->{report_meta}{'suite-name'},
                                                               $parsed_report->{report_meta}{'suite-type'}
                                                              )->id;

        foreach (keys %{$parsed_report->{db_meta}})
        {
                no strict 'refs';
                my $value = $parsed_report->{db_meta}->{$_};
                $self->{report}->$_ ($value) if defined $value;
        }
        $self->{report}->update;
}

sub _print_report
{
        my ($self, $parsed_report) = @_;

        say STDERR "Report: ", join(", ",
                                    $self->{report}->id,
                                    $self->{report}->successgrade,
                                    $parsed_report->{report_meta}{'suite-name'}."-".$parsed_report->{report_meta}{'suite-version'},
                                   );
        say STDERR "        ", $_->{section} foreach @{$parsed_report->{tap_sections}};
        say STDERR "";
}

sub post_process_request_hook
{
        my ($self) = shift;

        $self->write_tap_to_db();

        my $harness = new Artemis::TAP::Harness( tap => $self->{tap} );
        $harness->evaluate_report();
        $self->update_parsed_report_in_db( $harness->parsed_report );

        $self->_print_report($harness->parsed_report);
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
