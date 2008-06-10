package Artemis::Reports::Receiver;

use warnings;
use strict;

our $VERSION = '2.01';

use parent 'Net::Server::PreForkSimple';
use Artemis::Model 'model';
use TAP::Parser;

sub start_new_report {
        my $self = shift;

        $self->{report} = model('ReportsDB')->resultset('Report')->new({ tap => '' });
        $self->{report}->insert;
        print STDERR "report_id ", $self->{report}->id, " ($$)\n";
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

sub debug_print_raw_report
{
        my ($self) = shift;

        print STDERR "\n-----------------------------\n";
        print STDERR "TAP for report_id ", $self->{report}->id, " ($$)\n";
        print STDERR $self->{tap};
        print STDERR "-----------------------------\n";
}

sub write_tap_to_db
{
        my ($self) = shift;

        $self->{report}->tap( $self->{tap} );
        $self->{report}->update;
}

sub parse_tap
{
        my ($self) = shift;

        # TODO: should use ::Aggregator

        my $parser = TAP::Parser->new({ tap => $self->{tap} });
        $parser->run;

        while ( my $result = $parser->next ) {
                print STDERR "______________\n";
                print STDERR "  type: ", $result->type, ", is_ok: ", $result->is_ok, "\n";
        }
        my $planned = $parser->tests_planned;
        my $passed  = $parser->passed;
        my $failed  = $parser->failed;
        print STDERR "planned: ", $planned, "\n";
        print STDERR "passed:  ", $passed, "\n";
        print STDERR "failed:  ", $failed, "\n";


        if (not defined $planned and $passed and not $failed)
        {
                $self->{report}->successgrade ( 'PASS' );
        }
        elsif ($failed) {
                $self->{report}->successgrade ( 'FAIL' );
        }
        elsif ($planned == $passed) {
                $self->{report}->successgrade ( 'PASS' );
        }
        elsif ($planned != $passed) {
                $self->{report}->successgrade ( 'FAIL' );
        }
        $self->{report}->update;
        print STDERR "  ", $self->{report}->successgrade, "\n";
}

sub post_process_request_hook
{
        my ($self) = shift;

        $self->debug_print_raw_report();
        $self->write_tap_to_db();
        $self->parse_tap();
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
