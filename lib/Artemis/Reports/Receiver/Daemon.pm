package Artemis::Reports::Receiver::Daemon;

use 5.010;

use strict;
use warnings;

use Artemis::Config;
use Artemis::Reports::Receiver;
use Moose;

with 'MooseX::Daemonize';

has server => ( is => 'rw');
has port   => ( is => 'rw', isa => 'Int', default => sub { Artemis::Config->subconfig->{report_port} } );

after start => sub {
                    my $self = shift;

                    return unless $self->is_daemon;

                    $self->initialize_server;
                    $self->server->server_loop;
                   }
;

sub initialize_server
{
        my ($self) = @_;
        my $EUID = `id -u`; chomp $EUID;
        my $EGID = `id -g`; chomp $EGID;
        Artemis::Reports::Receiver->run(
                                        port         => $self->port,
                                        log_level    => 2,
                                        max_servers  => 100,
                                        user         => $EUID,
                                        group        => $EGID,
                                       );
}


sub run
{
        my ($self) = @_;
        my ($command) = @ARGV;
        return unless $command && grep /^$command$/, qw(start status restart stop);
        $self->$command;
        say $self->status_message;
}


1;

