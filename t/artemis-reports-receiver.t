#!/usr/bin/env perl

use strict;
use warnings;

use Class::C3;
use MRO::Compat;

use IO::Socket::INET;
use IO::Handle;

# use Log::Log4perl;
# use POSIX ":sys_wait_h";
# use String::Diff;
# use Sys::Hostname;
# use YAML::Syck;
# use Cwd;
# use TAP::DOM;
# use Artemis::MCP::Net;

use Artemis::Schema::TestTools;
use Test::Fixture::DBIC::Schema;
use Artemis::Reports::Receiver::Daemon;

use Test::More;
use Test::Deep;

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema,  fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
construct_fixture( schema  => reportsdb_schema,  fixture => 't/fixtures/reportsdb/report.yml' );
construct_fixture( schema  => hardwaredb_schema, fixture => 't/fixtures/hardwaredb/systems.yml' );
# -----------------------------------------------------------------------------------------------------------------

ok(1);

$ENV{MX_DAEMON_STDOUT} ||= '/tmp/artemis_reports_receiver_daemon_test_'.(getpwuid($<) || "unknown").'-stdout.log';
$ENV{MX_DAEMON_STDERR} ||= '/tmp/artemis_reports_receiver_daemon_test_'.(getpwuid($<) || "unknown").'-stderr.log';


my $pid = fork();
if ($pid == 0) {

        my $EUID = `id -u`; chomp $EUID;
        my $EGID = `id -g`; chomp $EGID;
        my $receiver = new Artemis::Reports::Receiver
            (
             port    => 7359,
             pidfile => '/tmp/artemis-reports-receiver-daemon-test-'.(getpwuid($<) || "unknown").'.pid',
             user    => $EUID,
             group   => $EGID,
            );
        $receiver->run;
}
else
{
        sleep 3;
        my $sock = IO::Socket::INET->new( PeerAddr  => 'localhost',
                                          PeerPort  => '7359',
                                          Proto     => 'tcp',
                                          ReuseAddr => 1,
                                        ) or die $!;

        is(ref($sock), 'IO::Socket::INET', "socket created");

        eval {
                local $SIG{ALRM} = sub { die "Timeout!" };
                alarm (3);
                my $answer = <$sock>;
                diag $answer;
                like ($answer, qr/^Artemis::Reports::Receiver\. Protocol is TAP\. Your report id: \d+/, "receiver api");
                $sock->print( "1..2\nok 1 affe\nok 2 zomtec\n");
        };
        alarm(0);
        ok (!$@, "Read and write in time");

        kill 15, $pid;
        sleep 3;
        kill 9, $pid;
}

ok(1);

# END {
#         $receiver->stop();
# }

done_testing();
