#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp qw(tempdir);
use FindBin;
use Test::More;

my $fixture = tempdir('readme-render-test.XXXXXX', TMPDIR => 1, CLEANUP => 0);
my $passed;
END {
    if ($passed) { require File::Path; File::Path::remove_tree($fixture); }
    else { warn "README renderer fixtures retained: $fixture\n"; }
}
my $helper = "$FindBin::Bin/render-cargo-readme-version.pl";
sub bytes {
    my ($path) = @_;
    open my $file, '<', $path or die $!;
    binmode $file or die $!;
    return do { local $/; <$file> } // '';
}
sub render {
    my ($source, $package, $version) = @_;
    open my $file, '>', "$fixture/input" or die $!;
    binmode $file or die $!;
    print {$file} $source or die $!;
    close $file or die $!;
    my $pid = fork(); defined $pid or die $!;
    if (!$pid) {
        open STDOUT, '>', "$fixture/output" or die $!;
        open STDERR, '>', "$fixture/error" or die $!;
        exec $^X, $helper, "$fixture/input", $package, $version;
        die "exec: $!";
    }
    waitpid($pid, 0);
    return ($?, bytes("$fixture/output"), bytes("$fixture/error"));
}
for my $case (
    [qq{ic-memory = "0.34"\n}, qq{ic-memory = "0.37.0"\n}],
    [qq{# caf\xc3\xa9\r\n  ic-memory='0.1' # keep "comment"\r\n},
     qq{# caf\xc3\xa9\r\n  ic-memory="0.37.0" # keep "comment"\r\n}],
    [qq{ic-memory = { features = ["a", "version = 'x'"], version = '0.13', default-features = false }\n},
     qq{ic-memory = { features = ["a", "version = 'x'"], version = "0.37.0", default-features = false }\n}],
    [q{'ic-memory' = { version = '0.1', }}, q{'ic-memory' = { version = "0.37.0", }}],
) {
    my ($status, $output, $error) = render($case->[0], 'ic-memory', '0.37.0');
    is($status, 0, 'supported example succeeds');
    is($output, $case->[1], 'only the selected version changes');
    is($error, '', 'supported example needs no reminder');
}
for my $source (
    '', "# no dependency\n", "ic-memory = \"unterminated\n",
    "ic-memory = \"0.1\"\nic-memory = \"0.2\"\n",
    'ic-memory = { path = "../ic-memory" }',
    'ic-memory = { version = "0.1", version = "0.2" }',
    'ic-memory = { version = "0.1", features = ["broken", }',
    'ic-memory = { version = "0.1", unknown = invalid }',
    'ic-memory = { version = true }',
    'ic-memory = "escaped\\n"',
) {
    my ($status, $output, $error) = render($source, 'ic-memory', '0.37.0');
    is($status, 0, 'advisory example never blocks release');
    is($output, $source, 'unsupported or ambiguous source stays unchanged');
    like($error, qr/Reminder:/, 'reminder explains unchanged source');
}
my ($status, $output) = render('other = "0.1"', 'other', '1.2.3');
is($status, 0, 'package selection is generic');
is($output, 'other = "1.2.3"', 'selected sibling package renders');
($status, $output) = render('other = "0.1"', '../bad', '1.2.3');
isnt($status, 0, 'invalid package refuses');
is($output, '', 'invalid invocation publishes no output');
($status, $output) = render('other = "0.1"', 'other', '01.2.3');
isnt($status, 0, 'noncanonical candidate refuses');
is($output, '', 'invalid version publishes no output');
done_testing();
$passed = Test::More->builder->is_passing;
