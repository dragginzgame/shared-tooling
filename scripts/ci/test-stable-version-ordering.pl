#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use File::Compare qw(compare);
use IPC::Open3;
use Symbol qw(gensym);
use POSIX qw(WIFEXITED WEXITSTATUS);

my $root = "$FindBin::Bin/../..";
sub run {
    my (@args) = @_;
    my $err = gensym;
    my $pid = open3(undef, my $out, $err, @args);
    my $stdout = do { local $/; <$out> } // "";
    my $stderr = do { local $/; <$err> } // "";
    waitpid($pid, 0) == $pid or die "cannot wait for version checker: $!\n";
    my $status = $?;
    unless (WIFEXITED($status)) {
        print STDERR $stdout, $stderr;
        die "version checker did not exit normally (wait status $status): @args\n";
    }
    return (WEXITSTATUS($status), $stdout, $stderr);
}
for my $case (
    ["0.1.1", "0.1.0", 1], ["0.1.0", "0.1.1", -1], ["1.0.0", "1.0.0", 0],
    ["0.9007199254740993.0", "0.9007199254740992.0", 1],
    ["18446744073709551615.0.0", "18446744073709551614.9.9", 1],
    ["18446744073709551616.0.0", "18446744073709551617.0.0", -1],
    ["0.10.0", "0.9.999", 1], ["1.0.0", "0.999.999", 1],
) {
    my ($status, $out, $err) = run($^X, "$root/scripts/ci/compare-stable-versions.pl", @$case[0, 1]);
    $status == 0 && $out eq "$case->[2]\n" && $err eq "" or die "ordering failed: @$case\n";
}
for my $invalid ("", "01.2.3", "1.2", "1.2.3-extra", "1.2.3\n", "a.b.c") {
    for my $side (0, 1) {
        my @args = ("1.2.3", "1.2.3"); $args[$side] = $invalid;
        my ($status, $out) = run($^X, "$root/scripts/ci/compare-stable-versions.pl", @args);
        $status != 0 && $out eq "" or die "invalid version accepted\n";
    }
}
my $scratch = tempdir("stable-version-order.XXXXXX", TMPDIR => 1, CLEANUP => 1);
my $input = "$scratch/notes";
open my $file, ">", $input or die $!;
print {$file} "# Changelog\n\n## [1.2.3]\n\n- Previous notes.\n"; close $file or die $!;
for my $version ("1.2.3", "1.2.2", "0.9.0") {
    my ($status) = run("awk", "-v", "version=$version", "-v", "previous=1.2.3", "-v", "date=2026-10-14",
        "-f", "$root/scripts/ci/finalize-release-changelog.awk", $input);
    $status != 0 or die "selector accepted a non-increasing target\n";
}
print "Exact stable version ordering and finalizer increase admission passed\n";
