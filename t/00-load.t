#!perl -T

use Test::More tests => 1;

use Class::C3;
use MRO::Compat;

BEGIN {
	use_ok( 'Artemis::Reports::Receiver' );
}

diag( "Testing Artemis::Reports::Receiver $Artemis::Reports::Receiver::VERSION, Perl $], $^X" );
