package Tapper::Reports::Receiver::Level2::Codespeed;

use strict;
use warnings;

use LWP::UserAgent;
use Data::DPath 'dpath';
use Scalar::Util "reftype";

sub submit
{
        my ($util, $report, $options) = @_;

        my $codespeed_url   = $options->{url};
        my $subscribe_dpath = $options->{subscribe_dpath};

        return unless $codespeed_url && $subscribe_dpath;

        my $tap_dom = $report->get_cached_tapdom;
        my @chunks = dpath($subscribe_dpath)->match($tap_dom);
        @chunks = @{$chunks[0]} while $chunks[0] && reftype $chunks[0] eq "ARRAY"; # deref all array envelops
        
        return unless @chunks;

        my $ua = LWP::UserAgent->new;
        $ua->post($codespeed_url."/result/add/", $_) foreach @chunks;
}

1;

=head1 NAME

Tapper::Reports::Receiver::Level2::Codespeed - Tapper - Level2 receiver plugin: Codespeed

=head1 ABOUT

I<Level 2 receivers> are other data receivers besides Tapper to
which data is forwarded when a report is arriving at the
Tapper::Reports::Receiver.

One example is Codespeed to track benchmark values.

By convention, for Codespeed the data is already prepared in the TAP
report like this:

 ok perlformance
   ---
   codespeed:
     -
       benchmark: Rx.regexes.fieldsplit1
       commitid: 1b1a3d2a
       environment: renormalist
       executable: perl-5.12.1-foo
       project: perl
       result_value: 2.58451795578003
     -
       benchmark: Rx.regexes.fieldsplit2
       commitid: 1b1a3d2b
       environment: renormalist
       executable: perl-5.12.1-foo
       project: perl
       result_value: 1.04680895805359
   ...
 ok some other TAP stuff

I.e., it requires a key C<codespeed:> containing an array of chunks
with keys that Codespeed is expecting.

=head1 SYNOPSIS

Used indirectly via L<Tapper::Reports::Receiver|Tapper::Reports::Receiver>.

 package Tapper::Reports::Receiver::Level2::Codespeed;

 sub submit
 {
        my ($util, $report, $options) = @_;
        # ... actual data forwarding here
 }

=head1 AUTHOR

AMD OSRC Tapper Team, C<< <tapper at amd64.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2011 AMD OSRC Tapper Team, all rights reserved.

This program is released under the following license: freebsd


=cut
