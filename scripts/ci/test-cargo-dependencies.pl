#!/usr/bin/env perl
# Shared companions: scripts/dev/cargo-dependencies.pl make/cargo-dependencies.mk
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir);
use FindBin qw($RealBin);
use JSON::PP;
use Test::More;
my $root = abs_path("$RealBin/../..");
make_path("$root/target/tmp");
my $fixture = tempdir('dependency-review-tests.XXXXXX', DIR => "$root/target/tmp", CLEANUP => 0);
my $complete;
END {
    if ($complete && Test::More->builder->is_passing) { remove_tree($fixture); }
    else { warn "Fixtures retained: $fixture\n"; }
}
sub write_file {
    my ($path, $text) = @_;
    open my $fh, '>', "$fixture/$path" or die $!;
    print {$fh} $text; close $fh or die $!;
}
make_path(map { "$fixture/$_" } qw(bin consumer/qualification consumer/extra));
for my $dir ('consumer', 'consumer/qualification', 'consumer/extra') {
    write_file("$dir/Cargo.toml", "[package]\nname = \"fixture\"\nversion = \"0.1.0\"\n");
    write_file("$dir/Cargo.lock", "original\n");
}
write_file('bin/cargo', <<'STUB');
#!/usr/bin/env perl
use strict; use warnings; use JSON::PP; use File::Basename qw(dirname);
open my $log, '>>', "$ENV{FIXTURE}/events" or die $!; print {$log} join("\t", @ARGV), "\n"; close $log;
my ($manifest) = map { $ARGV[$_+1] } grep { $ARGV[$_] eq '--manifest-path' } 0..$#ARGV;
my $root = dirname($manifest);
my $qualification = $root =~ /qualification$/;
if ($ARGV[0] eq 'update') {
 exit 23 if $ENV{FAIL_UPDATE} && $qualification;
 open my $lock, '>', "$root/Cargo.lock" or die $!; print {$lock} "updated\n"; close $lock; exit 0;
}
my $source = 'registry+https://github.com/rust-lang/crates.io-index';
my $version = $qualification ? '0.97.0' : '0.100.2';
$version = '1.2.1+spec-1.1.0' if $ENV{BUILD_METADATA};
my $dep = { name => 'sample', rename => 'renamed', req => $qualification ? '^0.97.0' : '^0.100.0', kind => 'dev',
 source => $source, optional => JSON::PP::false, target => 'cfg(unix)' };
my $result = { workspace_root => $root, workspace_members => ['root'],
 packages => [{ id => 'root', name => 'fixture', version => '0.1.0', dependencies => [$dep] },
 { id => 'dep', name => 'sample', version => $version, source => $ENV{PATCHED} ? undef : $source }],
 resolve => { nodes => [{id => 'root', deps => [{ name => 'renamed', pkg => 'dep',
 dep_kinds => [{kind => 'dev', target => 'cfg(unix)'}] }]}] }};
print encode_json($result);
exit 17 if $ENV{FAIL_METADATA} && $qualification;
STUB
write_file('bin/curl', <<'STUB');
#!/usr/bin/env perl
use strict; use warnings; use JSON::PP;
if (grep { $_ eq '--version' } @ARGV) { print "curl 8.10.0\n"; exit 0; }
die 'expected bounded parallel batch' unless grep { $_ eq '--parallel' } @ARGV;
my @outputs = map { $ARGV[$_+1] } grep { $ARGV[$_] eq '--output' } 0..$#ARGV;
open my $log, '>>', "$ENV{FIXTURE}/requests" or die $!; print {$log} "$_\n" for @outputs; close $log;
for my $output (@outputs) {
 open my $out, '>', $output or die $!;
 my @versions = $ENV{BUILD_METADATA} ? ('0.9.8','1.2.1+spec-1.1.0','1.2.1+other','1.3.0-beta.1') :
 ('0.97.0','0.100.2','0.101.0','0.102.0-beta.1');
 for my $v (@versions) {
  print {$out} encode_json({name => 'sample', vers => $v, yanked => $v eq '0.101.0' ? JSON::PP::true : JSON::PP::false}), "\n";
 }
 close $out or die $!;
}
exit 22 if $ENV{FAIL_REGISTRY};
STUB
chmod 0755, "$fixture/bin/cargo", "$fixture/bin/curl" or die $!;
my $real_path = $ENV{PATH};
local $ENV{PATH} = "$fixture/bin:$real_path";
local $ENV{FIXTURE} = $fixture;
sub run {
    my (@args) = @_;
    unlink "$fixture/events", "$fixture/requests";
    my $pid = fork(); defined $pid or die $!;
    if (!$pid) {
        open STDOUT, '>', "$fixture/output" or die $!;
        open STDERR, '>', "$fixture/errors" or die $!;
        exec $^X, "$root/scripts/dev/cargo-dependencies.pl", @args,
            '--consumer', "$fixture/consumer", '--json' or die $!;
    }
    waitpid $pid, 0; return $? >> 8;
}
sub read_file { open my $fh, '<', "$fixture/$_[0]" or die $!; local $/; return <$fh>; }
is(run('review'), 1, 'older qualification selection requires review');
my $report = decode_json(read_file('output'));
is_deeply($report->{manifests}, ['Cargo.toml','qualification/Cargo.toml'], 'both workspaces automatic');
is($report->{rows}[0]{status}, 'current', 'older manifest minimum does not make current lock stale');
is($report->{rows}[1]{latest}, '0.100.2', 'latest excludes yanked and prerelease beyond old range');
is($report->{rows}[1]{locked}[0], '0.97.0', 'renamed dev dependency resolved');
is(scalar @{$report->{differences}}, 1, 'cross-workspace difference reported');
is(read_file('consumer/Cargo.lock'), "original\n", 'review leaves root lock alone');
is(read_file('consumer/qualification/Cargo.lock'), "original\n", 'review leaves qualification lock alone');
is(scalar(split /\n/, read_file('requests')), 1, 'one registry observation for shared supplier');
{
 local $ENV{BUILD_METADATA} = 1;
 is(run('review'), 0, 'stable build metadata does not cause false upgrade or downgrade finding');
 is(decode_json(read_file('output'))->{rows}[0]{latest}, '1.2.1+spec-1.1.0', 'latest includes stable build metadata');
 is(run('update','--package','sample','--precise','1.2.1+spec-1.1.0'), 0, 'precise accepts stable build metadata');
}
is(run('update'), 0, 'successful updates do not fail for remaining newer releases');
is(decode_json(read_file('output'))->{review_status}, 1, 'JSON preserves outstanding review findings');
is(run('review','--manifest','extra/Cargo.toml'), 1, 'extra workspace explicitly selected');
is(scalar @{decode_json(read_file('output'))->{manifests}}, 3, 'extra workspace included');
{
 local $ENV{FAIL_METADATA} = 1;
 is(run('update'), 2, 'failed metadata with plausible JSON refuses update');
 unlike(read_file('events'), qr/^update/m, 'all workspaces admitted before any mutation');
 is(-e "$fixture/requests" ? 1 : 0, 0, 'failure does not query registry');
}
{
 local $ENV{FAIL_REGISTRY} = 1;
 is(run('review'), 2, 'failed registry with plausible payload is incomplete');
 is(read_file('output'), '', 'failed observation emits no success JSON');
}
{
 local $ENV{PATCHED} = 1;
 is(run('review'), 2, 'patched registry selections require separate source review');
 is(decode_json(read_file('output'))->{rows}[0]{status}, 'source-override', 'local patch is not registry freshness');
}
{
 local $ENV{FAIL_UPDATE} = 1;
 is(run('update','--package','sample','--precise','0.100.2'), 2, 'partial update failure stops');
 is(read_file('consumer/Cargo.lock'), "updated\n", 'earlier update retained');
 like(read_file('errors'), qr/locks may have changed; no rollback/, 'partial effects explicit');
 like(read_file('events'), qr/update\t-v\t.*--package\tsample\t--precise\t0.100.2/, 'scoped arguments forwarded');
}
is(run('update','--precise','0.100.2'), 2, 'invalid selectors rejected before Cargo');
is(-e "$fixture/events" ? 1 : 0, 0, 'invalid input has no command effects');
is(run('review','--manifest','../Cargo.toml'), 2, 'escaping manifest refused');
is(run('review','--package','missing'), 2, 'unknown package selection refused');

# Real Cargo proves discovery and independent resolution, without registry access.
local $ENV{PATH} = $real_path;
for my $pair (['consumer','product'], ['consumer/qualification','qualification']) {
    my ($dir,$name) = @$pair;
    make_path("$fixture/$dir/src");
    write_file("$dir/Cargo.toml", "[workspace]\n[package]\nname = \"$name\"\nversion = \"0.1.0\"\nedition = \"2021\"\n");
    write_file("$dir/src/lib.rs", '');
    unlink "$fixture/$dir/Cargo.lock";
    is(system('cargo','generate-lockfile','--offline','--manifest-path',"$fixture/$dir/Cargo.toml"), 0, "prepare real $name lock");
}
is(run('review'), 0, 'real independent workspaces with no suppliers');
is(run('update'), 0, 'real Cargo update handles both workspaces');
is_deeply(decode_json(read_file('output'))->{update_attempts}, ['Cargo.toml','qualification/Cargo.toml'], 'both real updates attempted');
is_deeply(decode_json(read_file('output'))->{changed_lockfiles}, [], 'real no-op update reports no changed locks');

# Exercise the public Make interface against real independent workspaces.
write_file('consumer/Makefile', "TOKO_TOOLING_ROOT := $root\nhelp:\n\t\@echo fixture-help\ninclude $root/make/cargo-dependencies.mk\n");
sub run_make {
    my (@args) = @_;
    my $pid = fork(); defined $pid or die $!;
    if (!$pid) {
        open STDOUT, '>', "$fixture/make-output" or die $!;
        open STDERR, '>', "$fixture/make-errors" or die $!;
        exec 'make', '--no-print-directory', '-C', "$fixture/consumer", @args or die $!;
    }
    waitpid $pid, 0; return $? >> 8;
}
is(run_make(), 0, 'including maintenance targets preserves default goal');
like(read_file('make-output'), qr/fixture-help/, 'consumer help remains default');
is(run_make('deps-help'), 0, 'Make help exposes review and mutation effects');
like(read_file('make-output'), qr/changes locks/, 'help names update effects');
is(run_make('deps-review'), 0, 'Make review invokes real Cargo');
like(read_file('make-output'), qr/Workspaces: Cargo.toml, qualification\/Cargo.toml/, 'Make covers both workspaces');
is(run_make('deps-update'), 0, 'Make update invokes real Cargo');
like(read_file('make-output'), qr/No lockfile changes\./, 'no-op update is explicit');
unlike(read_file('make-output'), qr/\e\[/, 'redirected output contains no ANSI escapes');
is(run_make('-n','deps-update'), 2, 'update execution guard rejects dry-run');
is(run_make('deps-review','DEPENDENCY_PRECISE=0.100.2'), 2, 'invalid Make selectors propagate failure');
{
    local $ENV{PATH} = "$fixture/bin:$real_path";
    unlink "$fixture/events";
    is(run_make('deps-update','DEPENDENCY_PACKAGE=sample','DEPENDENCY_PRECISE=0.100.2',
        'DEPENDENCY_MANIFEST=extra/Cargo.toml'), 0, 'successful update with review findings succeeds through Make');
    my $events = read_file('events');
    is(scalar(() = $events =~ /^update\t/gm), 3, 'Make dispatches root, qualification and explicit extra workspace');
    like($events, qr/--package\tsample\t--precise\t0.100.2/, 'Make forwards package and precise version');
    my $output = read_file('make-output');
    is(scalar(() = $output =~ /^sample /gm), 1, 'default output consolidates findings across workspaces');
    unlike($output, qr/ current|local-path/, 'default output omits current and local selections');
    like($output, qr/Lockfiles changed: Cargo.lock, qualification\/Cargo.lock/, 'actual lock changes explicitly reported');
    is(run_make('deps-review', 'DEPENDENCY_VERBOSE=1'), 2, 'review still returns findings status');
    like(read_file('make-output'), qr/ current /, 'verbose output includes current selections');
}
done_testing();
$complete = 1;
