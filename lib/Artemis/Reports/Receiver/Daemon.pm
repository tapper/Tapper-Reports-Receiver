package Artemis::Reports::Receiver::Daemon;

use 5.010;

use strict;
use warnings;

use Artemis::Config;
use Artemis::Reports::Receiver;
use Moose;

with 'MooseX::Daemonize';

after start => sub {
        my $self = shift;

        return unless $self->is_daemon;
        my $port = Artemis::Config->subconfig->{report_port};


        Artemis::Reports::Receiver->new()->run($port);
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

