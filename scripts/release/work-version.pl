#!/usr/bin/env perl
# Shared companions: scripts/ci/StableVersion.pm scripts/ci/validate-release-inputs.pl
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/../ci";
use StableVersion qw(stable version_cmp);
use File::Temp qw(tempdir);
use File::Copy qw(copy);

# VERSION-backed repositories only. Cargo release groups retain their own owner.
my ($operation, $kind) = @ARGV;
defined($operation) && (($operation =~ /\A(?:base|check)\z/ && @ARGV == 1) ||
    ($operation eq 'prepare' && @ARGV == 2 && $kind =~ /\A(?:patch|minor|major)\z/))
    or die "usage: work-version.pl base|check|prepare patch|minor|major\n";
sub read_file {
    my ($path) = @_;
    -f $path && !-l $path or die "expected regular file: $path\n";
    open my $file, '<', $path or die "read $path: $!\n";
    local $/;
    my $text = <$file>;
    close $file or die "close $path: $!\n";
    return $text;
}
sub write_file {
    my ($path, $text) = @_;
    open my $file, '>', $path or die "write $path: $!\n";
    print {$file} $text or die "write $path: $!\n";
    close $file or die "close $path: $!\n";
}
my $version = read_file('VERSION');
$version =~ s/\n\z//;
stable($version) or die "invalid VERSION\n";
my $notes = read_file('CHANGELOG.md');
my @headings = $notes =~ /^(##[ \t]+[^\n]*)/mg;
@headings or die "missing changelog version\n";
my ($top, $suffix) = $headings[0] =~ /\A##[ \t]+\[([^]]+)\](?:[ \t]+-[ \t]+(Unreleased|[0-9]{4}-[0-9]{2}-[0-9]{2}))?[ \t]*\z/;
defined($top) && stable($top) or die "invalid first changelog heading\n";
my $pending = defined($suffix) && $suffix eq 'Unreleased';
my $base = $version;
if ($pending && $top eq $version) {
    my ($previous) = ($headings[1] // '') =~ /\A##[ \t]+\[([^]]+)\]/;
    defined($previous) && stable($previous) && version_cmp($version, $previous) > 0
        or die "pending VERSION requires an older changelog release\n";
    $base = $previous;
}
if ($operation eq 'base') {
    # Legacy adapters may still have VERSION at the base and notes at the next
    # candidate. Their normal preflight owns candidate admission.
    print "$base\n";
    exit;
}
$top eq $version or die "VERSION $version disagrees with changelog $top\n";
# Historical headings can retain an old Unreleased suffix; the canonical base
# bounds history just as it does in the release finalizer.
for my $index (1 .. $#headings) {
    my ($other) = $headings[$index] =~ /\A##[ \t]+\[([^]]+)\]/;
    defined($other) && stable($other) && version_cmp($other, $version) < 0
        or die "duplicate, misplaced or invalid release heading\n";
}
exit if $operation eq 'check';

open my $next, '-|', $^X, "$RealBin/../ci/validate-release-inputs.pl", 'next-version', $base, $kind
    or die "start version selection: $!\n";
my $candidate = <$next>;
close $next or die "version selection failed\n";
chomp $candidate;
# Repeated work reuses the pending entry; a larger requested bump promotes it.
$candidate = $version if $pending && version_cmp($candidate, $version) < 0;
my $heading = "## [$candidate] - Unreleased";
if ($pending) {
    $notes =~ s/^\Q$headings[0]\E$/$heading/m;
} else {
    $notes =~ s/^(\Q$headings[0]\E)$/$heading\n\n$1/m;
}

# Keep recoverable originals and both candidates if either replacement fails.
# No index/ref operations or automatic release execution.
open my $git, '-|', 'git', 'rev-parse', '--git-dir' or die "locate Git directory: $!\n";
my $git_dir = <$git>;
close $git or die "not a Git checkout\n";
chomp $git_dir;
my $tag_status = system 'git', 'show-ref', '--verify', '--quiet', "refs/tags/v$candidate";
$tag_status == 256 or die $tag_status == 0
    ? "candidate v$candidate is already tagged; finalize its notes before new work\n"
    : "cannot inspect candidate tag\n";
my $scratch = tempdir('work-version.XXXXXX', DIR => $git_dir, CLEANUP => 0);
eval {
    for my $path ('CHANGELOG.md', 'VERSION') {
        copy($path, "$scratch/original-$path") or die "save $path: $!\n";
    }
    write_file("$scratch/candidate-CHANGELOG.md", $notes);
    write_file("$scratch/candidate-VERSION", "$candidate\n");
    for my $path ('CHANGELOG.md', 'VERSION') {
        copy("$scratch/candidate-$path", "$scratch/$path") or die "copy $path: $!\n";
        rename "$scratch/$path", $path or die "replace $path: $!\n";
    }
    1;
} or die "$@Work-version evidence retained: $scratch\n";
for my $path ('CHANGELOG.md', 'VERSION') {
    unlink "$scratch/original-$path", "$scratch/candidate-$path";
}
rmdir $scratch or die "remove completed scratch $scratch: $!\n";
print "$candidate\n";
