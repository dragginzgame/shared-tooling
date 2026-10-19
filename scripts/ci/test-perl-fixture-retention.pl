#!/usr/bin/env perl
# Shared companions: scripts/ci/test-no-symlinks.pl scripts/ci/test-license.pl scripts/ci/test-documentation-links.pl
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use Test::More;

my $fixture = tempdir('perl-retention.XXXXXX', TMPDIR => 1, CLEANUP => 0);
my $complete = 0;
END {
    my $status = $?;
    if (defined $fixture) {
        if ($complete && $status == 0 && Test::More->builder->is_passing) {
            my $errors;
            remove_tree($fixture, {error => \$errors});
            if (@$errors || -e $fixture || -l $fixture) {
                warn "Perl retention fixture cleanup incomplete: $fixture\n";
                $status = 1;
            }
        } else {
            warn "Perl retention fixtures retained: $fixture\n";
            $status ||= 1;
        }
    }
    $? = $status;
}
for my $name (qw(test-no-symlinks.pl test-license.pl test-documentation-links.pl)) {
    open my $source, '<', "$FindBin::Bin/$name" or die $!;
    my $text = do { local $/; <$source> };
    close $source or die $!;
    # Execute the actual allocation/END handler, stopping before any test body.
    # These fixtures' top-level END blocks close at column zero.
    $text =~ /\A(.*?^END \{.*?^\}\n)/ms or die "missing fixture END handler: $name\n";
    my $prefix = $1;
    for my $mode (qw(success premature die failed complete-failed cleanup-failed)) {
        my $run = "$fixture/$name-$mode";
        make_path("$run/tmp");
        open my $script, '>', "$run/probe.pl" or die $!;
        print {$script} $prefix, <<'PROBE' or die $!;
open my $marker, '>', "$fixture/retained-input" or die $!;
print {$marker} 'original evidence' or die $!;
close $marker or die $!;
my $mode = shift;
die "injected setup failure\n" if $mode eq 'die';
exit 0 if $mode eq 'premature';
ok($mode ne 'failed', 'injected assertion');
done_testing();
$complete = Test::More->builder->is_passing;
if ($mode eq 'cleanup-failed') {
    no warnings 'redefine';
    *main::remove_tree = sub { }; # Simulate cleanup leaving its input intact.
}
exit($mode eq 'complete-failed' ? 37 : 0);
PROBE
        close $script or die $!;
        my $pid = fork;
        defined($pid) or die $!;
        if (!$pid) {
            $ENV{TMPDIR} = "$run/tmp";
            open STDOUT, '>', "$run/result.log" or die $!;
            open STDERR, '>&', STDOUT or die $!;
            exec $^X, "$run/probe.pl", $mode;
            die "cannot execute probe: $!";
        }
        waitpid($pid, 0) == $pid or die $!;
        my $status = $?;
        if ($mode eq 'success') { is($status, 0, "$name completed success"); }
        elsif ($mode eq 'complete-failed') { is($status, 37 << 8, "$name preserves original exit"); }
        else { isnt($status, 0, "$name refuses $mode"); }
        opendir my $scratch, "$run/tmp" or die $!;
        my @retained = grep { $_ ne '.' && $_ ne '..' } readdir $scratch;
        closedir $scratch or die $!;
        is(scalar @retained, $mode eq 'success' ? 0 : 1, "$name $mode cleanup disposition");
        if (@retained) {
            open my $input, '<', "$run/tmp/$retained[0]/retained-input" or die $!;
            is(do { local $/; <$input> }, 'original evidence', "$name $mode keeps input bytes");
            close $input or die $!;
        }
    }
}
done_testing();
$complete = Test::More->builder->is_passing;
