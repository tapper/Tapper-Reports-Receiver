use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new
    (
     module_name         => 'Artemis::Reports::Receiver',
     license             => 'restrictive',
     dist_author         => 'OSRC SysInt Team <osrc-sysint@elbe.amd.com>',
     dist_version_from   => 'lib/Artemis/Reports/Receiver.pm',
     build_requires => {
                        'Test::More'    => 0,
                        'Artemis::Test' => 0,
                       },
     requires => {
                  'perl'                       => '5.010',
                  'Artemis::Config'            => '2.01',
                  'Artemis::Schema'            => '2.01',
                  'Artemis::TAP::Harness'      => 0,
                  'Net::Server::PreForkSimple' => 0,
                  'File::Basename'             => 0,
                  'Module::Build'              => 0,
                  'TAP::Parser'                => 0,
                  'File::Spec'                 => 0,
                  'Cwd'                        => 0,
                 },
     add_to_cleanup      => [ 'Artemis-Reports-Receiver-*' ],
    );

$builder->create_build_script();
