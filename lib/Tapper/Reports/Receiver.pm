package Tapper::Reports::Receiver;
# ABSTRACT: Tapper - Receiver for Tapper test reports as TAP or TAP::Archive

use 5.010;
use strict;
use warnings;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use IO::Handle;
use Moose;

use Tapper::Config;
use Tapper::Reports::Receiver::Util;

with 'MooseX::Log::Log4perl';

=head2 run

Execute the reports receiver.

=cut

sub run
{
        my ($self, $bind_port) = @_;
	my $condvar = AnyEvent->condvar;

        tcp_server undef, $bind_port, sub {
                my ($fh, $host, $port) = @_;
                return unless $fh;

                my $util      = Tapper::Reports::Receiver::Util->new();
                my $report_id = $util->start_new_report($host, $port);

                my $buffer;
		my $hdl; $hdl = AnyEvent::Handle->new(
                                                      fh       => $fh,
                                                      rtimeout => Tapper::Config->subconfig->{times}{receiver_timeout},
                                                      on_eof   => sub {
                                                              my $tap = $hdl->rbuf;
                                                              $hdl->destroy;
                                                              $util->process_request( $tap );
                                                      },
                                                      on_read  => sub {},
                                                      on_rtimeout => sub {
                                                              my $tap = $hdl->rbuf;
                                                              $hdl->destroy;
                                                              $self->log->error('timeout reached for reading TAP');
                                                              $util->process_request( $tap );
                                                      },
                                                      on_error => sub {
                                                              my $tap = $hdl->rbuf;
                                                              $hdl->destroy;
                                                              $util->process_request( $tap );
                                                      },
                                                     );

		$hdl->push_write(
                                 "Tapper::Reports::Receiver. ".
                                 "Protocol is TAP. ".
                                 "Your report id: $report_id".
                                 "\n"
		);
        };
	$condvar->recv;
}

1; # End of Tapper::Reports::Receiver
