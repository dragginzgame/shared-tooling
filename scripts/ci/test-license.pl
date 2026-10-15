#!/usr/bin/env perl
# Shared companions: scripts/ci/check-license.pl
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use Test::More;

my $root = "$FindBin::Bin/../..";
my $fixture = tempdir('license-check.XXXXXX', TMPDIR => 1, CLEANUP => 0);
END {
    if (defined $fixture) {
        if (Test::More->builder->is_passing) { remove_tree($fixture); }
        else { warn "License fixtures retained: $fixture\n"; }
    }
}
my $read = sub {
    open my $fh, '<', $_[0] or die $!;
    local $/;
    my $text = <$fh>;
    close $fh or die $!;
    return $text;
};
my $write = sub {
    open my $fh, '>', "$fixture/LICENSE" or die $!;
    print {$fh} $_[0];
    close $fh or die $!;
};
my $checker = "$root/scripts/ci/check-license.pl";
my $check = sub { system($^X, $checker, '--file', "$fixture/LICENSE", @_); };
my $mit = $read->("$root/licenses/MIT.txt");
my $dragginz = $read->("$root/licenses/Dragginz-ICP-Burn-1.0.txt");
for ($mit, $dragginz) {
    s/\Q{{COPYRIGHT_NOTICES}}\E/Copyright (c) 2024 Original contributors\nCopyright (c) 2026 New contributors/;
}
$write->($mit);
is($check->('--kind', 'mit'), 0, 'MIT with multiple preserved notices');
my $wrapped = $mit;
$wrapped =~ s/without restriction/without\nrestriction/;
$wrapped =~ s/\n/\r\n/g;
$write->($wrapped);
is($check->('--kind', 'mit'), 0, 'line wrapping and CRLF are immaterial');
$write->($dragginz);
is($check->('--kind', 'dragginz'), 0, 'Dragginz terms');
isnt($check->('--kind', 'mit'), 0, 'wrong policy rejected');
my $tampered = $dragginz;
$tampered =~ s/at least 20%/at least 0%/;
$write->($tampered);
isnt($check->('--kind', 'dragginz'), 0, 'weakened burn threshold rejected');
$tampered = $dragginz;
$tampered =~ s/"Organization" means Toko Studios Ltd\./"Organization" means every recipient./;
$write->($tampered);
isnt($check->('--kind', 'dragginz'), 0, 'expanded organization exception rejected');
$write->($mit . "Extra permission.\n");
isnt($check->('--kind', 'mit'), 0, 'additional terms rejected');
$tampered = $mit;
$tampered =~ s/Copyright[^\n]+\n//g;
$write->($tampered);
isnt($check->('--kind', 'mit'), 0, 'missing attribution rejected');
$write->($read->("$root/licenses/MIT.txt"));
isnt($check->('--kind', 'mit'), 0, 'unfilled template rejected');
my $prior = $read->("$root/licenses/prior-mit-notice.txt");
my $combined = $dragginz . "\n" . $prior . $mit;
$write->($combined);
is($check->('--kind', 'dragginz', '--prior-mit'), 0, 'explicit prior grant accepted');
isnt($check->('--kind', 'dragginz'), 0, 'undeclared appended grant rejected');
$write->($dragginz);
isnt($check->('--kind', 'dragginz', '--prior-mit'), 0, 'required prior notice missing');
$write->($combined . "\n" . $prior . $mit);
isnt($check->('--kind', 'dragginz', '--prior-mit'), 0, 'duplicate appendix rejected');
$write->($combined =~ s/Permission is hereby granted/Permission is not granted/r);
isnt($check->('--kind', 'dragginz', '--prior-mit'), 0, 'changed historical grant rejected');
$write->($mit);
isnt($check->('--kind', 'mit', '--prior-mit'), 0, 'invalid option combination');
isnt($check->('--kind', 'unknown'), 0, 'unknown license rejected');
isnt(system($^X, $checker, '--kind', 'mit', '--file', "$fixture/missing"), 0, 'missing file rejected');
# Exercise the snapshot layout without a moving sibling dependency.
make_path("$fixture/snapshot/scripts/ci", "$fixture/snapshot/licenses");
copy($checker, "$fixture/snapshot/scripts/ci/check-license.pl") or die $!;
my ($companions) = $read->($checker) =~ /^# Shared companions: (.+)$/m;
defined($companions) or die "missing snapshot companion declaration";
for my $name (split / /, $companions) {
    copy("$root/$name", "$fixture/snapshot/$name") or die $!;
}
$checker = "$fixture/snapshot/scripts/ci/check-license.pl";
$write->($combined);
is($check->('--kind', 'dragginz', '--prior-mit'), 0, 'relocated snapshot resolves its own templates');
$write->($mit);
is($check->('--kind', 'mit'), 0, 'recovery after rejected inputs');
done_testing();
