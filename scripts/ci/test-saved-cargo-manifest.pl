#!/usr/bin/env perl
# Shared companions: scripts/ci/render-cargo-workspace-version.pl
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use FindBin;
use JSON::PP qw(encode_json decode_json);
use Test::More;

my $fixture = tempdir('saved-manifest.XXXXXX', TMPDIR => 1, CLEANUP => 0);
my $passed;
END {
    if ($passed) { remove_tree($fixture); }
    else { warn "Saved manifest evidence retained: $fixture\n"; }
}
my $helper = "$FindBin::Bin/render-cargo-workspace-version.pl";
sub write_file {
    my ($path, $bytes) = @_;
    open my $file, '>:raw', $path or die $!;
    print {$file} $bytes or die $!;
    close $file or die $!;
}
sub render {
    my ($path, $version, $context) = @_;
    write_file("$fixture/context.json", encode_json($context));
    my $pid = fork();
    defined $pid or die $!;
    if (!$pid) {
        open STDOUT, '>:raw', "$fixture/output" or die $!;
        open STDERR, '>:raw', "$fixture/error" or die $!;
        exec {$^X} $^X, $helper, $path, '0.18.6', $version, "$fixture/context.json";
        die $!;
    }
    waitpid($pid, 0);
    my $status = $?;
    open my $file, '<:raw', "$fixture/output" or die $!;
    my $output = do { local $/; <$file> };
    close $file or die $!;
    return ($status, $output);
}
my $root = "$fixture/live source";
make_path("$root/crates/owned", "$fixture/archive");
write_file("$root/crates/owned/Cargo.toml", "[package]\nname = \"owned\"\nversion = \"0.18.6\"\n");
my $manifest = <<'TOML';
# Preserve this and the unrelated external version verbatim.
[workspace]
members = ["crates/owned"]
[workspace.package]
version = "0.18.6"
[workspace.dependencies]
renamed = { package = "owned", path = "crates/owned", version = "^0.18" }
external = { path = "../external", version = "7.8" }
[workspace.dependencies.exact]
package = "owned"
path = "crates/owned"
version = "=0.18.6"
TOML
write_file("$root/Cargo.toml", $manifest);
write_file("$fixture/archive/Cargo.toml", $manifest);
my $context = {
    source_root => $root,
    members => [{name => 'owned', manifest_path => "$root/crates/owned/Cargo.toml"}],
    manifest => {workspace => {dependencies => {
        renamed => {package => 'owned', path => 'crates/owned', version => '^0.18'},
        exact => {package => 'owned', path => 'crates/owned', version => '=0.18.6'},
        external => {path => '../external', version => '7.8'},
    }}},
};
my %live_context = %$context;
delete $live_context{source_root};
for my $candidate ('0.18.6', '0.18.7', '0.19.0', '1.0.0') {
    my ($major, $minor) = split /\./, $candidate;
    my $expected = $manifest;
    $expected =~ s/version = "0\.18\.6"/version = "$candidate"/;
    $expected =~ s/\^0\.18/\^$major.$minor/;
    $expected =~ s/=0\.18\.6/=$candidate/;
    my ($status, $bytes) = render("$root/Cargo.toml", $candidate, \%live_context);
    is($status, 0, "$candidate live projection succeeds");
    is($bytes, $expected, "$candidate live projection preserves other bytes");
    ($status, $bytes) = render("$fixture/archive/Cargo.toml", $candidate, $context);
    is($status, 0, "$candidate saved projection succeeds");
    is($bytes, $expected, "$candidate saved projection equals live projection");
}
# Saved identity must not depend on whether yesterday's workspace still exists.
rename $root, "$fixture/retained-source" or die $!;
my ($status, $bytes) = render("$fixture/archive/Cargo.toml", '0.19.0', $context);
is($status, 0, 'saved projection works without the original workspace');
like($bytes, qr/version = "\^0\.19"/, 'owned requirement still advances');
($status, $bytes) = render("$fixture/archive/Cargo.toml", '0.19.0', \%live_context);
ok($status != 0, 'missing live ownership refuses rather than silently omitting edits');
is($bytes, '', 'failed identity emits no candidate');
for my $case ('relative-root', 'newline-root', 'null-root', 'missing-member-path', 'mismatched-member', 'duplicate-member', 'literal-mismatch') {
    my $invalid = decode_json(encode_json($context));
    if ($case eq 'relative-root') { $invalid->{source_root} = 'relative'; }
    elsif ($case eq 'newline-root') { $invalid->{source_root} .= "\n"; }
    elsif ($case eq 'null-root') { $invalid->{source_root} = undef; }
    elsif ($case eq 'missing-member-path') { delete $invalid->{members}[0]{manifest_path}; }
    elsif ($case eq 'mismatched-member') { $invalid->{members}[0]{manifest_path} .= '.other'; }
    elsif ($case eq 'duplicate-member') { push @{$invalid->{members}}, $invalid->{members}[0]; }
    else { $invalid->{manifest}{workspace}{dependencies}{renamed}{version} = '^0.17'; }
    ($status, $bytes) = render("$fixture/archive/Cargo.toml", '0.19.0', $invalid);
    ok($status != 0, "$case refuses");
    is($bytes, '', "$case publishes no partial candidate");
}
open my $source, '<:raw', "$fixture/archive/Cargo.toml" or die $!;
is(do { local $/; <$source> }, $manifest, 'saved input remains byte-identical');
close $source or die $!;
my $unicode_context = decode_json(encode_json($context));
$unicode_context->{source_root} = '/saved/' . chr(0xe9) . ' source';
$unicode_context->{members}[0]{manifest_path} = $unicode_context->{source_root} . '/crates/owned/Cargo.toml';
($status, $bytes) = render("$fixture/archive/Cargo.toml", '0.19.0', $unicode_context);
is($status, 0, 'recorded Unicode identity needs no filesystem reconstruction');
like($bytes, qr/version = "\^0\.19"/, 'Unicode identity selects the same owned requirement');
my $unsupported = $manifest;
$unsupported =~ s/version = "0\.18\.6"/version = '0.18.6'/;
write_file("$fixture/archive/unsupported.toml", $unsupported);
($status, $bytes) = render("$fixture/archive/unsupported.toml", '0.19.0', $context);
ok($status != 0, 'unsupported root literal refuses');
is($bytes, '', 'unsupported literal emits no candidate');
$passed = Test::More->builder->is_passing;
done_testing();
