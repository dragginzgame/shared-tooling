#!/usr/bin/env perl
# Shared companions: scripts/ci/shared-package-version.pl scripts/ci/StableVersion.pm scripts/ci/validate-release-inputs.pl
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/../ci";
use StableVersion qw(stable version_cmp);
use File::Temp qw(tempdir);
use File::Copy qw(copy);

# Shared Tooling root package only. Consumer release groups retain their own owner.
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
sub manifest_version {
    my ($text)=@_;
    # Delegate the exact root-manifest convention to the shared reader.
    require IPC::Open2;
    my $pid=IPC::Open2::open2(my $out,my $in,$^X,"$RealBin/../ci/shared-package-version.pl",'-');
    print {$in} $text; close $in or die "write manifest reader: $!\n";
    local $/; my $value=<$out>; close $out; waitpid($pid,0);
    $?==0 or die "invalid package manifest\n";
    $value =~ s/\n\z//; return $value;
}
my $manifest=read_file('Cargo.toml');
my $version=manifest_version($manifest);
my $notes = read_file('CHANGELOG.md');
my @headings = $notes =~ /^(##[ \t]+[^\n]*)/mg;
@headings or die "missing changelog version\n";
my ($top, $suffix) = $headings[0] =~ /\A##[ \t]+\[([^]]+)\](?:[ \t]+-[ \t]+(Unreleased|[0-9]{4}-[0-9]{2}-[0-9]{2}))?[ \t]*\z/;
defined($top) && stable($top) or die "invalid first changelog heading\n";
my $pending = defined($suffix) && $suffix eq 'Unreleased';
# A normal main push is Shared's delivery boundary even when historical notes
# retain Unreleased. Read local remote-tracking evidence; never fetch implicitly.
if ($pending && $operation ne 'check') {
    my $ref = 'refs/remotes/origin/main';
    my $status = system 'git', 'show-ref', '--verify', '--quiet', $ref;
    if ($status == 0) {
        open my $tree,'-|','git','ls-tree','--name-only',$ref,'--','Cargo.toml' or die "inspect pushed version source: $!\n";
        my $entry=<$tree>; close $tree or die "cannot inspect pushed manifest\n";
        my $version_path=defined($entry) ? 'Cargo.toml' : 'VERSION';
        open my $remote, '-|', 'git', 'show', "$ref:$version_path"
            or die "read pushed package.version: $!\n";
        local $/;
        my $pushed = <$remote>;
        close $remote or die "cannot read pushed package.version\n";
        $pushed = manifest_version($pushed) if $version_path eq 'Cargo.toml';
        $pushed =~ s/\n\z//;
        stable($pushed) or die "invalid pushed package.version\n";
        $pending = 0 if $pushed eq $top;
    } elsif ($status != 256) {
        die "cannot inspect pushed version reference\n";
    }
}
my $base = $version;
if ($pending && $top eq $version) {
    my ($previous) = ($headings[1] // '') =~ /\A##[ \t]+\[([^]]+)\]/;
    defined($previous) && stable($previous) && version_cmp($version, $previous) > 0
        or die "pending package.version requires an older changelog release\n";
    $base = $previous;
}
$top eq $version or die "package.version $version disagrees with changelog $top\n";
if ($operation eq 'base') {
    print "$base\n";
    exit;
}
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
    for my $path ('CHANGELOG.md', 'Cargo.toml') {
        copy($path, "$scratch/original-$path") or die "save $path: $!\n";
    }
    write_file("$scratch/candidate-CHANGELOG.md", $notes);
    my $candidate_manifest=$manifest;
    $candidate_manifest =~ s/^(version[ \t]*=[ \t]*")\Q$version\E(")/$1$candidate$2/m
        or die "cannot update package.version\n";
    manifest_version($candidate_manifest) eq $candidate or die "candidate manifest disagrees\n";
    write_file("$scratch/candidate-Cargo.toml", $candidate_manifest);
    for my $path ('CHANGELOG.md', 'Cargo.toml') {
        copy("$scratch/candidate-$path", "$scratch/$path") or die "copy $path: $!\n";
        rename "$scratch/$path", $path or die "replace $path: $!\n";
    }
    1;
} or die "$@Work-version evidence retained: $scratch\n";
for my $path ('CHANGELOG.md', 'Cargo.toml') {
    unlink "$scratch/original-$path", "$scratch/candidate-$path";
}
rmdir $scratch or die "remove completed scratch $scratch: $!\n";
print "$candidate\n";
