#!/usr/bin/env perl
use strict;
use warnings;

# Pure exact ordering. No shell arithmetic, numeric coercion or metadata writes.
@ARGV == 2 or die "usage: compare-stable-versions.pl VERSION BASELINE\n";
my $canonical = qr/(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)/;
for (@ARGV) { /\A$canonical\z/ or die "expected canonical stable version\n"; }
my @candidate = split /\./, $ARGV[0];
my @baseline = split /\./, $ARGV[1];
my $order = 0;
for my $index (0 .. 2) {
    next if $candidate[$index] eq $baseline[$index];
    $order = length($candidate[$index]) <=> length($baseline[$index]);
    $order ||= $candidate[$index] cmp $baseline[$index];
    $order = $order < 0 ? -1 : 1;
    last;
}
print "$order\n" or die "version comparison output: $!\n";
close STDOUT or die "version comparison output: $!\n";
