#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Artemis::Reports::Receiver' );
}

diag( "Testing Artemis::Reports::Receiver $Artemis::Reports::Receiver::VERSION, Perl $], $^X" );
