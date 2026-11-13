#!/usr/bin/env perl
# Shared companions: scripts/dev/cargo-dependencies.pl make/cargo-dependencies.mk
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir);
use FindBin qw($RealBin);
use Test::More;
my $root = abs_path("$RealBin/../..");
make_path("$root/target/tmp");
my $fixture = tempdir('deps-update-tests.XXXXXX', DIR => "$root/target/tmp", CLEANUP => 0);
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
sub read_file { open my $fh, '<', "$fixture/$_[0]" or die $!; local $/; return <$fh>; }
make_path(map { "$fixture/$_" } qw(bin consumer/qualification consumer/extra));
for my $dir ('consumer', 'consumer/qualification', 'consumer/extra') {
    make_path("$fixture/$dir/src");
    my $name = $dir; $name =~ s{.*/}{};
    write_file("$dir/Cargo.toml", "[workspace]\n[package]\nname = \"$name\"\nversion = \"0.1.0\"\nedition = \"2021\"\n");
    write_file("$dir/src/lib.rs", '');
}
write_file('consumer/Makefile', "TOKO_TOOLING_ROOT := $root\nhelp:\n\t\@echo fixture-help\ninclude $root/make/cargo-dependencies.mk\n");
write_file('bin/cargo', <<'STUB');
#!/usr/bin/env perl
use strict; use warnings;
$ARGV[0] eq 'update' && $ARGV[1] eq '-v' or die 'unexpected Cargo command';
open my $fh, '>>', "$ENV{FIXTURE}/events" or die $!;
print {$fh} join("\t", @ARGV), "\n"; close $fh;
print "Cargo stdout\n"; warn "Cargo stderr\n";
exit 23 if $ENV{FAIL_UPDATE} && grep { /qualification\/Cargo.toml$/ } @ARGV;
STUB
chmod 0755, "$fixture/bin/cargo" or die $!;
local $ENV{FIXTURE} = $fixture;
my $real_path = $ENV{PATH};
local $ENV{PATH} = "$fixture/bin:$real_path";
sub run {
    my (@args) = @_;
    unlink "$fixture/events";
    my $pid = fork(); defined $pid or die $!;
    if (!$pid) {
        open STDOUT, '>', "$fixture/output" or die $!;
        open STDERR, '>', "$fixture/errors" or die $!;
        exec 'make', '--no-print-directory', '-C', "$fixture/consumer", @args or die $!;
    }
    waitpid $pid, 0; return $? >> 8;
}
is(run(), 0, 'consumer default goal preserved');
like(read_file('output'), qr/fixture-help/, 'consumer help remains default');
is(run('deps-update'), 0, 'updates succeed');
my $events = read_file('events');
is(scalar(split /\n/, $events), 2, 'only two Cargo update calls');
like($events, qr/qualification\/Cargo.toml/, 'qualification included');
like(read_file('output'), qr/Cargo stdout/, 'stdout streamed');
like(read_file('errors'), qr/Cargo stderr/, 'stderr streamed');
is(run('deps-update','DEPENDENCY_MANIFEST=extra/Cargo.toml','DEPENDENCY_PACKAGE=sample','DEPENDENCY_PRECISE=1.2.3'), 0, 'explicit extra and package selectors');
is(scalar(split /\n/, read_file('events')), 3, 'explicit extra workspace included');
like(read_file('events'), qr/--package\tsample\t--precise\t1.2.3/, 'selectors forwarded');
{
    local $ENV{FAIL_UPDATE} = 1;
    is(run('deps-update','DEPENDENCY_MANIFEST=extra/Cargo.toml'), 2, 'Cargo failure reaches Make');
    is(scalar(split /\n/, read_file('events')), 2, 'failure stops before extra workspace');
    like(read_file('errors'), qr/Error 23/, 'Cargo exit status preserved');
}
is(run('deps-update','DEPENDENCY_MANIFEST=../Cargo.toml'), 2, 'escaping manifest rejected');
ok(!-e "$fixture/events", 'invalid paths rejected before any update');
is(run('-n','deps-update'), 2, 'execution guard rejects dry-run');
ok(!-e "$fixture/events", 'dry-run never calls Cargo');
{
    local $ENV{PATH} = $real_path;
    local $ENV{CARGO_NET_OFFLINE} = 'true';
    is(run('deps-list'), 0, 'real offline inventory works without lockfiles');
    ok(!-e "$fixture/consumer/Cargo.lock" && !-e "$fixture/consumer/qualification/Cargo.lock", 'inventory creates no lockfiles');
    like(read_file('output'), qr/qualification\/Cargo.toml\s+-\s+qualification\s+0\.1\.0/, 'private workspace shown separately');
    unlike(read_file('output'), qr/publication status/, 'normal inventory has no explanatory footer');
    make_path("$fixture/consumer/ci");
    write_file('consumer/ci/cargo-release-groups.json', '{"groups":[{"name":"core","members":["consumer"]}]}');
    is(run('deps-list'), 0, 'grouped inventory succeeds');
    like(read_file('output'), qr/Cargo.toml\s+core\s+consumer\s+0\.1\.0/, 'joins actual package version to group');
    write_file('consumer/ci/cargo-release-groups.json', '{"groups":[{"name":"core","members":["missing"]}]}');
    is(run('deps-list'), 2, 'unknown group member refused');
    unlike(read_file('output'), qr/WORKSPACE/, 'invalid inventory does not print a partial table');
    unlink "$fixture/consumer/ci/cargo-release-groups.json";
    is(run('deps-update'), 0, 'real Cargo updates independent workspaces without existing locks');
    ok(-f "$fixture/consumer/Cargo.lock" && -f "$fixture/consumer/qualification/Cargo.lock", 'Cargo owns both lockfiles');
    is(run('deps-update'), 0, 'real no-op update succeeds');
}
done_testing();
$complete = 1;
