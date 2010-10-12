use strict;
use warnings;

use inc::Module::Install;

name     'Artemis-Reports-Receiver';
all_from 'lib/Artemis/Reports/Receiver.pm';
author   'OSRC SysInt Team <osrc-sysint@elbe.amd.com>';
license  'freebsd';

build_requires 'Test::More'         => 0;
build_requires 'Test::Perl::Critic' => 0;
build_requires 'Artemis::Test'      => '2.010004';

requires 'Artemis::Config'            => '2.010072';
requires 'Artemis::Schema'            => '2.010084';
requires 'Artemis::TAP::Harness'      => '2.010033';
requires 'Cwd'                        => 0;
requires 'File::Basename'             => 0;
requires 'File::Spec'                 => 0;
requires 'Module::Build'              => 0;
requires 'Moose'                      => 0;
requires 'MooseX::Daemonize'          => 0;
requires 'Net::Server::PreForkSimple' => 0;
requires 'TAP::Parser'                => 0;
requires 'DateTime::Format::Natural'  => 0;
requires 'DateTime::Format::Mail'     => 0;
requires 'perl'                       => '5.010';

WriteAll;

