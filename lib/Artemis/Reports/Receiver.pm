package Artemis::Reports::Receiver;

use strict;
use warnings;

our $VERSION = '2.01';

use parent 'Net::Server::PreForkSimple';
use Artemis::Model 'model';
use TAP::Parser;
use TAP::Parser::Aggregator;
use YAML::Syck;
use Data::Dumper;

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

sub parse_tap_
{
        my ($self) = shift;

        # TODO: should use ::Aggregator, or ::Harness

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
        print STDERR "passed:  ", $passed,  "\n";
        print STDERR "failed:  ", $failed,  "\n";


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
sub parse_tap
{
        my ($self) = shift;

        my @tap_sections = ();

        my $parser = TAP::Parser->new({ tap => $self->{tap} });


        my $i = 0;
        my %section;
        my $looks_like_prove_output = 0;
        my $re_prove_section = qr/^([-_\d\w\/.]*\w)\.+$/;
        my $re_artemis_meta  = qr/^#\s*(Artemis-)([-\w]+):(.+)$/i;
        my %meta = (
                    'suite-name' => 'unknown',
                    'suite-type' => 'unknown',
                   );

        while ( my $line = $parser->next ) {

                my $raw        = $line->raw;
                my $is_plan    = $line->is_plan;
                my $is_unknown = $line->is_unknown;

                # print STDERR "  looks_like_prove_output: $looks_like_prove_output ($is_unknown): $raw\n";

                if ( $is_unknown and $raw =~ $re_prove_section ) {
                        # print STDERR "  SET looks_like_prove_output\n";
                        $looks_like_prove_output ||= 1;
                }

                # ----- store previous section, start new section -----

                # start new section
                if (
                    $i == 0 or
                    ( not $looks_like_prove_output and $is_plan ) or
                    ( $looks_like_prove_output and $raw =~ $re_prove_section )
                   )
                {
                        #print STDERR "  cond 1\n" if ( $i == 0 );
                        #print STDERR "  cond 2\n" if ( not $looks_like_prove_output and $is_plan );
                        #print STDERR "  cond 3\n" if ( $looks_like_prove_output and $raw =~ $re_prove_section );

                        print STDERR "    new TAP section ", $line->raw, "\n";
                        if (keys %section) {
                                print STDERR "    push TAP section\n";
                                push @tap_sections, { %section };
                        }
                        %section = ();
                }


                # ----- extract some meta information -----

                # a normal TAP line and not a summary line from "prove"
                if ( not $is_unknown and not ($looks_like_prove_output and $raw =~ /^ok$/) ) {
                        $section{raw} .= "$raw\n";
                }

                # looks like filename line from "prove"
                if ( $is_unknown and $raw =~ $re_prove_section )
                {
                        $section{section} //= $1;
                        print STDERR "  ", $section{section}, "\n";
                }

                # Artemis meta line
                if ( $line->is_comment and $raw =~ $re_artemis_meta )
                {
                        my $key = lc $2;
                        my $val = $3;
                        $val =~ s/^\s+//;
                        $val =~ s/\s+$//;
                        $meta{$key} = $val;
                        print STDERR "      Artemis meta [$key:$val]\n";
                }

                $i++;
        }
        # store last section
        print STDERR "    push TAP section ", $section{section},"\n";
        push @tap_sections, { %section } if keys %section;

        # augment section names
        for (my $i = 0; $i < @tap_sections; $i++) {
                $tap_sections[$i]->{section} //= "report-$i";
        }

        print STDERR "________________________________ Suite: ",($meta{'suite-name'} || ''), "\n";
        #print STDERR Dumper(\@tap_sections);
        print STDERR Dumper(\%meta);
        print STDERR "________________________________\n";
        print STDERR "  $_\n" foreach map { $_->{section} } @tap_sections;

        # aggregate
        my $aggregator = TAP::Parser::Aggregator->new;
        $aggregator->start;
        foreach my $section (@tap_sections) {
                my $parser = TAP::Parser->new({ tap => $section->{raw} });
                $parser->run;
                $aggregator->add( $section->{section} => $parser );
        }
        $aggregator->stop;

        my $passed  = $aggregator->passed;
        my $failed  = $aggregator->failed;
        my $status  = $aggregator->get_status;
        print STDERR "passed:  ", $passed, "\n";
        print STDERR "failed:  ", $failed, "\n";
        print STDERR "status:  ", $status, "\n";


        $self->{report}->successgrade ( $status );
        $self->{report}->suite_id ( $self->get_suite($meta{'suite-name'}, $meta{'suite-type'})->id );

        my @allowed_keys = qw/machine-name
                              machine-description
                              ram cpuinfo
                              lspci
                              uname
                              osname
                              language-description
                              xen-changeset
                              starttime-test-program
                              duration
                              xen-dom0-kernel
                              xen-base-os-description
                              xen-guests-description
                              flags
                              reportcomment
                             /;
        foreach my $key (@allowed_keys)
        {
                no strict 'refs';
                my $value = $meta{$key};
                my $accessor = $key;
                $accessor =~ s/-/_/g;
                $self->{report}->$accessor( $value ) if defined $value;
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
