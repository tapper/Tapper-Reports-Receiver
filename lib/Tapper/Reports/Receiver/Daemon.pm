package Tapper::Reports::Receiver::Daemon;

use 5.010;

use strict;
use warnings;

use Tapper::Config;
use Tapper::Reports::Receiver;
use Moose;

with 'MooseX::Daemonize';

after start => sub {
                    my $self = shift;

                    return unless $self->is_daemon;
        my $port = Tapper::Config->subconfig->{report_port};


        Tapper::Reports::Receiver->new()->run($port);
};



sub run
{
        my ($self) = @_;
        my ($command) = @ARGV;
        return unless $command && grep /^$command$/, qw(start status restart stop);
        $self->$command;
        say $self->status_message;
}


1;

