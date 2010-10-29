#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Artemis::Reports::Receiver;

my $tap_archive = 't/tap-archive-1.tgz';

my $filecontent;
my $FH;
open $FH, "<", $tap_archive and do
{
        local $/;
        $filecontent = <$FH>;
        close $FH;
};

# ------------------------------------------------------------

my $arr = Artemis::Reports::Receiver->new;
$arr->{tap} = $filecontent;
is ($arr->tap_mimetype, 'application/x-gzip', "TAP mimetype - compressed");
is($arr->tap_is_archive, 1, "TAP archive recognized");

# ------------------------------------------------------------

$arr->{tap} = "1..2
ok
ok
";
is ($arr->tap_mimetype, 'text/plain', "TAP mimetype - text");
is($arr->tap_is_archive, 0, "TAP text recognized");

# ------------------------------------------------------------

done_testing();
