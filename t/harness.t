#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::Reports::Receiver::Harness;

my $tap = q{
t/00-artemis-meta.t...................
1..1
ok 1 - artemis-test-meta
# Artemis-Suite-Name:              Artemis
# Artemis-Suite-Version:           2.010004
# Artemis-Suite-Type:              library
# Artemis-Language-Description:    Perl 5.010000, /2home/ss5/perl510/bin/perl
# Artemis-Machine-Name:            bascha
# Artemis-uname:                   Linux bascha 2.6.24-18-generic #1 SMP Wed May 28 19:28:38 UTC 2008 x86_64 GNU/Linux
# Artemis-osname:                  Ubuntu 8.04
# Artemis-cpuinfo:                 2 cores [AMD Athlon(tm) 64 X2 Dual Core Processor 6000+]
# Artemis-ram:                     1887MB
# Artemis-starttime-test-program:  Fri Jun 13 11:16:35 CEST 2008
ok
t/00-load.t...........................
1..12
ok 1 - use Artemis;
ok 2 - use Artemis::Db::Handling;
ok 3 - use Artemis::Installer::Client;
ok 4 - use Artemis::Installer::Server;
ok 5 - use Artemis::MCP;
ok 6 - use Artemis::MCP::Builder;
ok 7 - use Artemis::MCP::RunloopDaemon;
ok 8 - use Artemis::MCP::Runtest;
ok 9 - use Artemis::MCP::XMLRPC;
ok 10 - use Artemis::PRC::PRC;
ok 11 - use Artemis::Schema;
Subroutine initialize redefined at /2home/ss5/perl510/lib/site_perl/5.10.0/Class/C3.pm line 70.
Subroutine uninitialize redefined at /2home/ss5/perl510/lib/site_perl/5.10.0/Class/C3.pm line 88.
Subroutine reinitialize redefined at /2home/ss5/perl510/lib/site_perl/5.10.0/Class/C3.pm line 101.
ok 12 - use Artemis::Schema::TestsDB;
# Testing Artemis 2.010004, Perl 5.010000, /2home/ss5/perl510/bin/perl
ok
t/artemis_logging_netlogappender.t....
1..5
ok 1 - use Artemis::Logging::NetLogAppender;
ok 2 # SKIP Please fix me!
ok 3 # SKIP Please fix me!
ok 4 # SKIP Please fix me!
ok 5 # SKIP Please fix me!
ok
t/artemis_mcp_builder.t...............
1..1
ok 1 - use Artemis::MCP::Builder;
ok
t/artemis_mcp_runtest.t...............
1..1
ok 1 - use Artemis::MCP::Runtest;
ok
t/artemis_model.t.....................
1..1
ok 1 - version count
ok
t/artemis_systeminstaller.t...........
1..9
ok 1 - use Artemis::Installer::Client;
ok 2 - gethostname by host
ok 3 # SKIP mocking still failes
ok 4 # SKIP mocking still failes
ok 5 # SKIP mocking still failes
ok 6 - Detected ISO correctly.
ok 7 - Detected tar.gz correctly.
ok 8 - Detected tgz correctly.
ok 9 - Detected tar correctly.
ok
t/artemis.t...........................
1..7
ok 1 - Subconfig during tests
not ok 2 - mcp host # TODO original config values need to be transferred here

#   Failed (TODO) test 'mcp host'
#   at t/artemis.t line 15.
#          got: undef
#     expected: '165.204.85.37'
not ok 3 - mcp host during live # TODO original config values need to be transferred here

#   Failed (TODO) test 'mcp host during live'
#   at t/artemis.t line 19.
#          got: undef
#     expected: '165.204.85.71'
ok 4 - Subconfig during live environment
ok 5 - ARTEMIS_LIVE set back
ok 6 - Subconfig during development
ok 7 - HARNESS_ACTIVE set back
ok
t/boilerplate.t.......................
1..3
ok 1 - README contains no boilerplate text
ok 2 - Changes contains no boilerplate text
ok 3 - lib/Artemis.pm contains no boilerplate text
ok
t/experiments.t.......................
1..2
ok 1
ok 2
Bummer 1
Bummer 2
Bummer 3
satz: Ein affe$1 kommt selten allein.
Bummer 1
Bummer 2
Bummer 3
satz: Ein affe$1 kommt selten allein.
satz2: Ein affeer kommt selten allein.
ok
All tests successful.
Files=10, Tests=42,  2 wallclock secs ( 0.06 usr  0.01 sys +  1.78 cusr  0.16 csys =  2.01 CPU)
Result: PASS
};

# ============================================================

plan tests => 19;

my $harness = new Artemis::Reports::Receiver::Harness( tap => $tap );

$harness->parse_tap_into_sections();
$harness->aggregate_sections();
$harness->process_meta_information();

is(scalar @{$harness->parsed_report->{tap_sections}}, 10, "count sections");

is($harness->parsed_report->{report_meta}->{'suite-name'},             'Artemis',                                                            "report meta suite name");
is($harness->parsed_report->{report_meta}->{'suite-version'},          '2.010004',                                                           "report meta suite version");
is($harness->parsed_report->{report_meta}->{'suite-type'},             'library',                                                            "report meta suite type");
is($harness->parsed_report->{report_meta}->{'language-description'},   'Perl 5.010000, /2home/ss5/perl510/bin/perl',                         "report meta language description");
is($harness->parsed_report->{report_meta}->{'machine-name'},           'bascha',                                                             "report meta machine name");
is($harness->parsed_report->{report_meta}->{'uname'}, 'Linux bascha 2.6.24-18-generic #1 SMP Wed May 28 19:28:38 UTC 2008 x86_64 GNU/Linux', "report meta uname");
is($harness->parsed_report->{report_meta}->{'osname'},                 'Ubuntu 8.04',                                                        "report meta osname");
is($harness->parsed_report->{report_meta}->{'cpuinfo'},                '2 cores [AMD Athlon(tm) 64 X2 Dual Core Processor 6000+]',           "report meta cpuinfo");
is($harness->parsed_report->{report_meta}->{'ram'},                    '1887MB',                                                             "report meta ram");
is($harness->parsed_report->{report_meta}->{'starttime-test-program'}, 'Fri Jun 13 11:16:35 CEST 2008',                                      "report meta starttime test program");

is($harness->parsed_report->{db_meta}->{'suite_version'}, '2.010004',                                                                    "db meta suite version");
is($harness->parsed_report->{db_meta}->{'language_description'}, 'Perl 5.010000, /2home/ss5/perl510/bin/perl',                           "db meta language description");
is($harness->parsed_report->{db_meta}->{'machine_name'}, 'bascha',                                                                       "db meta machine name");
is($harness->parsed_report->{db_meta}->{'uname'}, 'Linux bascha 2.6.24-18-generic #1 SMP Wed May 28 19:28:38 UTC 2008 x86_64 GNU/Linux', "db meta uname");
is($harness->parsed_report->{db_meta}->{'osname'}, 'Ubuntu 8.04',                                                                        "db meta osname");
is($harness->parsed_report->{db_meta}->{'cpuinfo'}, '2 cores [AMD Athlon(tm) 64 X2 Dual Core Processor 6000+]',                          "db meta cpuinfo");
is($harness->parsed_report->{db_meta}->{'ram'}, '1887MB',                                                                                "db meta ram");
is($harness->parsed_report->{db_meta}->{'starttime_test_program'}, 'Fri Jun 13 11:16:35 CEST 2008',                                      "db meta starttime test program");


