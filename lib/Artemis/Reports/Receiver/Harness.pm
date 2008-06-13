package Artemis::Reports::Receiver::Harness;

use 5.010;

use strict;
use warnings;

use TAP::Parser;
use TAP::Parser::Aggregator;

use Moose;

has tap           => ( is => 'rw', isa => 'Str'     );
has parsed_report => ( is => 'rw', isa => 'HashRef', default => sub {{}} );


# return sections
sub parse_tap_into_sections
{
        my ($self) = @_;

        $self->parsed_report->{tap_sections} = [];

        my $parser = new TAP::Parser ({ tap => $self->tap });

        my $i = 0;
        my %section;
        my $looks_like_prove_output = 0;
        my $re_prove_section = qr/^([-_\d\w\/.]*\w)\.+$/;
        my $re_artemis_meta  = qr/^#\s*(Artemis-)([-\w]+):(.+)$/i;
        my $re_artemis_meta_section  = qr/^#\s*(Artemis-Section:)\s*(.+)$/i;
        $self->parsed_report->{report_meta} = {
                                               'suite-name'    => 'unknown',
                                               'suite-version' => 'unknown',
                                               'suite-type'    => 'unknown',
                                              };

        while ( my $line = $parser->next )
        {
                my $raw        = $line->raw;
                my $is_plan    = $line->is_plan;
                my $is_unknown = $line->is_unknown;

                # prove section
                if ( $is_unknown and $raw =~ $re_prove_section ) {
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
                        if (keys %section) {
                                push @{$self->parsed_report->{tap_sections}}, { %section };
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
                        $section{section_name} //= $2;
                }

                # looks like artemis meta line
                if ( $line->is_comment and $raw =~ $re_artemis_meta )
                {
                        my $key = lc $2;
                        my $val = $3;
                        $val =~ s/^\s+//;
                        $val =~ s/\s+$//;
                        $self->parsed_report->{report_meta}{$key} = $val;
                        $section{section_name} //= $val if $raw =~ $re_artemis_meta_section;
                }

                $i++;
        }

        # store last section
        push @{$self->parsed_report->{tap_sections}}, { %section } if keys %section;

        # augment section names
        for (my $i = 0; $i < @{$self->parsed_report->{tap_sections}}; $i++)
        {
                $self->parsed_report->{tap_sections}->[$i]->{section_name} //= sprintf("section-%03d", $i);
        }
}

sub aggregate_sections
{
        my ($self) = shift;

        my $aggregator = new TAP::Parser::Aggregator;

        $aggregator->start;
        foreach my $section (@{$self->parsed_report->{tap_sections}})
        {
                my $parser = new TAP::Parser ({ tap => $section->{raw} });
                $parser->run;
                $aggregator->add( $section->{section_name} => $parser );
        }
        $aggregator->stop;

        $self->parsed_report->{successgrade} = $aggregator->get_status;
}

sub process_meta_information
{
        my ($self) = shift;

        my @allowed_keys = qw(
                                     machine-name
                                     machine-description
                                     suite-version
                                     ram
                                     cpuinfo
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
                            );
        foreach my $key (@allowed_keys)
        {
                my $value = $self->parsed_report->{report_meta}{$key};
                my $accessor = $key;
                $accessor =~ s/-/_/g;
                $self->parsed_report->{db_meta}{$accessor} = $value if defined $value;
        }
}

sub evaluate_report
{
        my ($self) = shift;

        $self->parse_tap_into_sections();
        $self->aggregate_sections();
        $self->process_meta_information();
}

1;
