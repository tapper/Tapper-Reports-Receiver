#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Data::Dumper;
use DateTime::Format::Natural;

plan tests => 7;

my $value = 'Wed Aug  6 10:20:54 CEST 2008';

my $dt = DateTime::Format::Natural->new->parse_datetime($value );
isa_ok( $dt, 'DateTime', "isa DateTime" );
is($dt->year, "2008", "it's 2008");
is($dt->day, "6", "it's 6th");
is($dt->month, "8", "it's august");
TODO: {
        local $TODO = "Why is there that big difference?";

        is($dt->hour, "10", "it's 10 o'clock");
        is($dt->min, "20", "it's 20min after 10");
        is($dt->sec, "54", "it's nearly the next minute");
}
print STDERR "time string:    ". Dumper($value);
print STDERR "parsed natural: ". Dumper($dt);
