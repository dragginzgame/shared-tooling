#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp qw(tempdir);
use FindBin;
use Test::More;

my $fixture = tempdir('workspace-render-test.XXXXXX', TMPDIR => 1, CLEANUP => 0);
my $passed;
END {
    if ($passed) { require File::Path; File::Path::remove_tree($fixture); }
    else { warn "Workspace renderer fixtures retained: $fixture\n"; }
}
my $helper = "$FindBin::Bin/render-cargo-workspace-version.pl";
my $source = "$fixture/Cargo.toml";
sub write_file {
    my ($path, $text) = @_;
    open my $file, '>', $path or die $!;
    binmode $file or die $!;
    print {$file} $text or die $!;
    close $file or die $!;
}
sub read_file {
    my ($path) = @_;
    open my $file, '<', $path or die $!;
    binmode $file or die $!;
    return do { local $/; <$file> } // '';
}
sub run {
    my (@args) = @_;
    my $pid = fork(); defined $pid or die $!;
    if (!$pid) {
        open STDOUT, '>', "$fixture/output" or die $!;
        open STDERR, '>', "$fixture/error" or die $!;
        exec $^X, $helper, @args;
        die "exec: $!";
    }
    waitpid($pid, 0);
    return ($?, read_file("$fixture/output"));
}
sub manifest {
    my ($version, $newline, $trailing) = @_;
    return join $newline,
        '# Preserve comments and unrelated identities.',
        '[workspace]', 'members = []',
        '  [ workspace.package ] # selected table',
        "\tversion = \"$version\"  # only this value changes",
        'description = "untouched metadata"',
        '[workspace.dependencies]', 'other = "0.1.0"', $trailing;
}
for my $newline ("\n", "\r\n") {
    for my $trailing ('', 'tail = "no final newline"') {
        my $text = manifest('0.1.0', $newline, $trailing);
        write_file($source, $text);
        my ($status, $output) = run($source, '0.1.0', '0.2.0');
        is($status, 0, 'literal manifest accepted');
        is($output, manifest('0.2.0', $newline, $trailing),
            'comments, whitespace, line endings and foreign versions preserved');
        is(read_file($source), $text, 'source unchanged');
    }
}
my $large = '999999999999999999999999999999999999999';
write_file($source, "[workspace.package]\nversion = \"$large.0.0\"\n");
my ($status, $output) = run($source, "$large.0.0", "$large.0.1");
is($status, 0, 'large canonical components compare as strings');
is($output, "[workspace.package]\nversion = \"$large.0.1\"\n", 'large component preserved');

my @refused = (
    ["[workspace]\n", '0.1.0', '0.2.0'],
    ["[workspace.package]\nedition = \"2021\"\n", '0.1.0', '0.2.0'],
    ["[workspace.package]\nversion = \"0.1.0\"\n" x 2, '0.1.0', '0.2.0'],
    ["[workspace.package]\nversion = \"0.1.0\"\nversion = \"0.1.0\"\n", '0.1.0', '0.2.0'],
    ["[workspace.package]\nversion = '0.1.0'\n", '0.1.0', '0.2.0'],
    ["['workspace'.'package']\nversion = \"0.1.0\"\n", '0.1.0', '0.2.0'],
    ["workspace.package.version = \"0.1.0\"\n", '0.1.0', '0.2.0'],
    ["[workspace.package]\nversion = \"0.1.0\" trailing\n", '0.1.0', '0.2.0'],
    ["[workspace.package]\nversion = \"0.1.0\"\n", '0.1.1', '0.2.0'],
    ["[workspace.package]\nversion = \"0.1.0\"\n", '00.1.0', '0.2.0'],
    ["[workspace.package]\nversion = \"0.1.0\"\n", '0.1.0', '0.2.0-beta'],
    ["[workspace.package]\nversion = \"0.1.0\"\n", '0.1.0', "0.2.0\n"],
);
for my $case (@refused) {
    my ($text, $previous, $candidate) = @$case;
    write_file($source, $text);
    ($status, $output) = run($source, $previous, $candidate);
    isnt($status, 0, 'unsupported or conflicting literal selection refused');
    is($output, '', 'refusal emits no partial candidate');
    is(read_file($source), $text, 'refused source unchanged');
}
write_file($source, "[workspace.package]\nversion = \"0.1.0\"\n");
symlink $source, "$fixture/alias" or die $!;
for my $args (
    [], [$source, '0.1.0'], [$source, '0.1.0', '0.2.0', 'extra'],
    ["$fixture/missing", '0.1.0', '0.2.0'],
    ["$fixture", '0.1.0', '0.2.0'],
    ["$fixture/alias", '0.1.0', '0.2.0'],
) {
    ($status, $output) = run(@$args);
    isnt($status, 0, 'invalid invocation/input refused');
    is($output, '', 'input refusal emits no candidate');
}
$passed = Test::More->builder->is_passing;
done_testing;
