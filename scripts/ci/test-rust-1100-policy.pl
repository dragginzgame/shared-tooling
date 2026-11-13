#!/usr/bin/env perl
# Shared companions: Cargo.toml
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir);
use FindBin qw($RealBin);
use JSON::PP qw(decode_json);
use Test::More;

my $root = abs_path("$RealBin/../..");
make_path("$root/target/tmp");
my $fixture = tempdir('rust-1100-policy.XXXXXX', DIR => "$root/target/tmp");
my $complete;
END {
    if ($complete && Test::More->builder->is_passing) { remove_tree($fixture); }
    else { warn "Rust policy evidence retained: $fixture\n"; }
}
sub write_file {
    my ($path, $text) = @_;
    open my $fh, '>', "$fixture/$path" or die $!;
    print {$fh} $text; close $fh or die $!;
}
sub read_file {
    open my $fh, '<', $_[0] or die $!;
    local $/; return <$fh>;
}
my $producer = read_file("$root/Cargo.toml");
my ($lints) = $producer =~ /(\[lints\.cargo\].*)/s;
defined $lints or die "missing producer lint policy\n";
$lints =~ s/^\[lints\./[workspace.lints./mg;
my $manifest = "[workspace]\nmembers = [\"app\", \"dep\"]\nresolver = \"3\"\n$lints";
my $package = "[package]\nname = \"policy-app\"\nversion = \"0.0.0\"\nedition = \"2024\"\nrust-version = \"1.100.0\"\n";
my $inherit = "\n[lints]\nworkspace = true\n";
make_path("$fixture/app/src", "$fixture/dep/src");
write_file('Cargo.toml', $manifest);
write_file('app/Cargo.toml', $package . $inherit);
write_file('dep/Cargo.toml', "[package]\nname = \"policy-dep\"\nversion = \"0.0.0\"\nedition = \"2024\"\n$inherit");
write_file('dep/src/lib.rs', "//! Fixture supplier.\n");
my $valid = "//! Fixture application.\n/// Answer.\n#[must_use]\npub fn answer() -> u32 { 42 }\n";
write_file('app/src/lib.rs', $valid);
local $ENV{CARGO_NET_OFFLINE} = 'true';
local $ENV{CARGO_BUILD_WARNINGS} = 'deny';
local $ENV{CARGO_TARGET_DIR} = "$fixture/target";
local $ENV{RUSTUP_AUTO_INSTALL} = '0';
sub run {
    my ($name, @args) = @_;
    my $pid = fork(); defined $pid or die $!;
    if (!$pid) {
        chdir $fixture or die $!;
        open STDOUT, '>', "$fixture/$name.out" or die $!;
        open STDERR, '>', "$fixture/$name.err" or die $!;
        exec 'cargo', @args or die $!;
    }
    waitpid $pid, 0;
    return $? == -1 ? 255 : ($? & 127) ? 128 + ($? & 127) : $? >> 8;
}
sub refuses {
    my ($name, $diagnostic, @args) = @_;
    isnt(run($name, @args), 0, "$name refused");
    like(read_file("$fixture/$name.err"), $diagnostic, "$name reports intended diagnostic");
}
is(run('valid', 'check', '--workspace'), 0, 'inherited producer policy accepts clean packages');
write_file('Cargo.toml', $manifest . "\n[workspace.dependencies]\npolicy-dep = { path = \"dep\" }\n");
refuses('unused-catalog', qr/unused.workspace.dependencies|unused workspace dependency/i, 'check', '--workspace');
write_file('Cargo.toml', $manifest);
write_file('app/Cargo.toml', $package . "\n[dependencies]\npolicy-dep = { path = \"../dep\" }\n$inherit");
refuses('unused-edge', qr/unused.dependenc/i, 'check', '--workspace');
write_file('app/Cargo.toml', $package . $inherit);
write_file('Cargo.toml', $manifest . "\n[workspace.package]\ndescription = \"Unused metadata\"\n");
refuses('unused-field', qr/unused.workspace.package|unused workspace package/i, 'check', '--workspace');
write_file('Cargo.toml', $manifest);
write_file('app/Cargo.toml', $package);
refuses('inheritance', qr/missing.lints.inheritance|lints.*inherit/i, 'check', '--workspace');
write_file('app/Cargo.toml', $package . $inherit);
my $unknown = $manifest;
$unknown =~ s/unknown_lints = "deny"/unknown_lints = "deny"\nmade_up_lint = "deny"/;
write_file('Cargo.toml', $unknown);
refuses('unknown', qr/unknown.*lint/i, 'check', '--workspace');
write_file('Cargo.toml', $manifest);
write_file('app/src/lib.rs', "//! Fixture.\n/// | A | B |\n/// |---|---|\n/// | value | extra | discarded |\npub fn answer() {}\n");
refuses('table', qr/invalid.markdown.table|table.*column|column.*table/i, 'doc', '--no-deps', '-p', 'policy-app');
write_file('app/src/lib.rs', "//! Fixture.\n/// Answer.\npub fn answer() -> u32 { let unused_value = 1; 42 }\n");
{
    local $ENV{CARGO_TARGET_DIR} = "$fixture/cold-target";
    refuses('strict-cold', qr/warnings are denied|generated 1 warning/i, 'check', '-p', 'policy-app');
}
{
    local $ENV{CARGO_BUILD_WARNINGS} = 'warn';
    is(run('warm', 'check', '-p', 'policy-app', '--message-format=json'), 0, 'warm warning-producing build succeeds in warn mode');
}
isnt(run('strict-warm', 'check', '-p', 'policy-app', '--message-format=json-render-diagnostics'), 0, 'deny mode rejects warnings on warm rendered output');
my @records = map { decode_json($_) } grep { /^\{/ } split /\n/, read_file("$fixture/strict-warm.out");
my @artifacts = grep { ($_->{reason} // '') eq 'compiler-artifact' } @records;
ok(@artifacts && !(grep { !$_->{fresh} } @artifacts), 'warning enforcement reuses fresh artifacts without recompilation');
write_file('app/src/lib.rs', $valid);
is(run('valid-docs', 'doc', '--no-deps', '-p', 'policy-app'), 0, 'clean documentation passes the same Rustdoc policy');
is(run('clippy', 'clippy', '--workspace'), 0, 'strict Cargo warning mode accepts clean Clippy');
write_file('app/src/lib.rs', "//! Fixture.\n/// Answer.\npub fn answer() -> u32 { let x = 42; return x; }\n");
refuses('clippy-warning', qr/needless_return|unneeded.*return/i, 'clippy', '-p', 'policy-app');
done_testing();
$complete = 1;
