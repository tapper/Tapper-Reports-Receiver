use strict;
use warnings;

use inc::Module::Install;

name     'Tapper-Reports-Receiver';
all_from 'lib/Tapper/Reports/Receiver.pm';
author   'AMD OSRC Tapper Team <tapper@amd64.org>';
license  'freebsd';

build_requires 'Test::More'         => 0;
build_requires 'Test::Perl::Critic' => 0;
build_requires 'Tapper::Test'       => "3.000002";
build_requires 'File::Slurp'        => 0;

author_requires 'Module::Install::WriteAll';
 
requires 'Tapper::Config'             => "3.000002";
requires 'Tapper::Schema'             => "3.000002";
requires 'Tapper::TAP::Harness'       => "3.000002";
requires 'Cwd'                        => 0;
requires 'File::Basename'             => 0;
requires 'File::Spec'                 => 0;
requires 'File::MimeInfo::Magic'      => 0;
requires 'IO::Scalar'                 => 0;
requires 'Module::Build'              => 0;
requires 'Moose'                      => 0;
requires 'MooseX::Daemonize'          => 0;
requires 'MooseX::Log::Log4perl'      => "0.42";
requires 'Net::Server::PreForkSimple' => 0;
requires 'TAP::Parser'                => 0;
requires 'DateTime::Format::Natural'  => 0;
requires 'DateTime::Format::Mail'     => 0;
requires 'AnyEvent'                   => 0;
requires 'EV'                         => 0;
requires 'perl'                       => '5.010';

install_script glob('bin/*');

WriteAll;

