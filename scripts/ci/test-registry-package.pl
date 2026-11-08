#!/usr/bin/env perl
# Shared companions: scripts/distribution/registry-package.pl
use strict;
use warnings;
use Archive::Tar;
use Digest::SHA qw(sha256_hex);
use File::Temp qw(tempdir);
use FindBin;
use Test::More;
my $root = "$FindBin::Bin/../..";
mkdir "$root/target" unless -d "$root/target";
my $fixture = tempdir('registry-package.XXXXXX', DIR=>"$root/target", CLEANUP=>0);
my $complete = 0;
END {
    if ($complete) { require File::Path; File::Path::remove_tree($fixture); }
    else { warn "Registry package fixture retained: $fixture\n"; }
}
my $reader = "$root/scripts/distribution/registry-package.pl";
my $count = 0;
sub archive {
    my (@entries) = @_;
    my $tar = Archive::Tar->new;
    for my $entry (@entries) { $tar->add_data(@$entry); }
    my $path = "$fixture/" . ++$count . '.crate';
    $tar->write($path, 1) or die 'write fixture archive';
    open my $f, '<:raw', $path or die $!;
    local $/; my $checksum = sha256_hex(<$f>);
    return ($path, $checksum);
}
sub extract {
    my ($archive, $checksum, $version) = @_;
    my $out = "$fixture/out-$count";
    return (system($^X, $reader, 'extract', $archive, $checksum, $version // '0.33.0', $out), $out);
}
my @base = (
    ['toko-tooling-0.33.0/Cargo.toml', "[package]\nname = \"toko-tooling\"\nversion = \"0.33.0\"\n"],
    ['toko-tooling-0.33.0/scripts/distribution/refresh-consumer.sh', "#!/bin/sh\n", {mode=>0755}],
);
my ($archive, $checksum) = archive(@base);
my ($status, $out) = extract($archive, $checksum);
is($status, 0, 'valid authenticated package extracts');
ok(-x "$out/scripts/distribution/refresh-consumer.sh", 'archive executable mode preserved');
is(system($^X, $reader, 'read', $out, 'Cargo.toml'), 0, 'selected member is independently readable');
open my $edit, '>>', "$out/Cargo.toml" or die $!; print {$edit} '# corrupt'; close $edit;
isnt(system($^X, $reader, 'read', $out, 'Cargo.toml'), 0, 'modified unpacked member refuses');
for my $case (
    ['traversal', 'toko-tooling-0.33.0/../escape', 'bad'],
    ['absolute', '/escape', 'bad'],
    ['foreign root', 'other-0.33.0/file', 'bad'],
    ['control character', "toko-tooling-0.33.0/line\nfile", 'bad'],
    ['symlink', 'toko-tooling-0.33.0/link', '', {type=>'2', linkname=>'Cargo.toml'}],
    ['hardlink', 'toko-tooling-0.33.0/link', '', {type=>'1', linkname=>'Cargo.toml'}],
    ['duplicate', 'toko-tooling-0.33.0/Cargo.toml', 'bad'],
    ['inventory injection', 'toko-tooling-0.33.0/.toko-tooling.files.json', '{}'],
    ['Git state injection', 'toko-tooling-0.33.0/.git/config', 'bad'],
    ['parent collision', 'toko-tooling-0.33.0/scripts', 'bad'],
) {
    my ($label, @entry) = @$case;
    my ($file, $sha) = archive(@base, \@entry);
    my ($result, $destination) = extract($file, $sha);
    isnt($result, 0, "$label refuses");
    ok(!-e $destination, "$label refuses before writing payloads");
}
($archive, $checksum) = archive(@base);
($status, $out) = extract($archive, '0' x 64);
isnt($status, 0, 'wrong archive checksum refuses');
ok(!-e $out, 'wrong checksum writes no payloads');
($archive, $checksum) = archive([$base[0][0], $base[0][1]]);
($status) = extract($archive, $checksum);
isnt($status, 0, 'marker-only package refuses');
($archive, $checksum) = archive(@base);
($status) = extract($archive, $checksum, '0.33.1');
isnt($status, 0, 'wrong selected version refuses');
done_testing;
$complete = Test::More->builder->is_passing;
