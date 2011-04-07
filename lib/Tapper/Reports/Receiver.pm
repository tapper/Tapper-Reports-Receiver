package Tapper::Reports::Receiver;

use 5.010;
use strict;
use warnings;

our $VERSION = '3.000010';

use AnyEvent;
use AnyEvent::Socket;
use EV;
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
        tcp_server undef, $bind_port, sub {
                my ($fh, $host, $port) = @_;
                return unless $fh;
                $fh->autoflush(1);

                my $util      = Tapper::Reports::Receiver::Util->new();
                my $report_id = $util->start_new_report($host, $port);
                $fh->say( "Tapper::Reports::Receiver. ",
                          "Protocol is TAP. ",
                          "Your report id: $report_id");


                my $condvar = AnyEvent->condvar;

                my $message='';
                my $read_watcher; 
                $read_watcher = AnyEvent->io
                  (
                   fh   => $fh,
                   poll => 'r',
                   cb   => sub{
                           my $received_bytes = sysread $fh, $message, 1024, length $message;
                           if ($received_bytes <= 0) {
                                   undef $read_watcher;
                                   $condvar->send($message);
                           }
                   }
               );
                my $timeout_watcher = 
                  AnyEvent->timer (
                                   after => Tapper::Config->subconfig->{times}{receiver_timeout},
                                   cb    => sub {
                                           $self->log->error('timeout reached for reading TAP');
                                           $condvar->send($message);
                     });
                my $tap = $condvar->recv;
                $util->process_request($tap);
        };
        EV::loop;
}

1;


=head1 NAME

Tapper::Reports::Receiver - Tapper - Receiver for Tapper test reports as TAP or TAP::Archive


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
