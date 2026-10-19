#!/usr/bin/env perl
# Shared companions: scripts/ci/check-license.pl
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use Test::More;
use Archive::Tar;
use IO::Compress::Gzip qw(gzip $GzipError);

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
my $dragginz = $read->("$root/licenses/Dragginz-ICP-Burn-1.1.txt");
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
$tampered =~ s/twenty percent \(20%\)/zero percent (0%)/ or die 'burn clause not found';
$write->($tampered);
isnt($check->('--kind', 'dragginz'), 0, 'weakened burn threshold rejected');
$tampered = $dragginz;
$tampered =~ s/"Organization" means Toko Studios Ltd,/"Organization" means every recipient,/ or die 'organization definition not found';
$write->($tampered);
isnt($check->('--kind', 'dragginz'), 0, 'expanded organization exception rejected');
$write->($mit . "Extra permission.\n");
isnt($check->('--kind', 'mit'), 0, 'additional terms rejected');
$tampered = $dragginz;
$tampered =~ s/irrevocable and sublicensable/revocable and sublicensable/ or die 'permanent patent grant not found';
$write->($tampered);
isnt($check->('--kind', 'dragginz'), 0, 'weakened permanent patent grant rejected');
my $historical = $read->("$root/licenses/Dragginz-ICP-Burn-1.0.txt");
$historical =~ s/\Q{{COPYRIGHT_NOTICES}}\E/Copyright (c) 2026 Original contributors/;
$write->($historical);
is($check->('--kind', 'dragginz', '--license-version', '1.0'), 0, 'historical terms explicitly selected');
isnt($check->('--kind', 'dragginz'), 0, 'historical terms do not pass latest policy');
$write->($dragginz);
is($check->('--kind', 'dragginz', '--license-version', '1.1'), 0, 'latest terms explicitly selected');
isnt($check->('--kind', 'dragginz', '--license-version', '2.0'), 0, 'unknown license version rejected');
isnt($check->('--kind', 'mit', '--license-version', '1.1'), 0, 'MIT has no Dragginz version selector');
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
$write->($mit);
rename "$fixture/LICENSE", "$fixture/regular-license" or die $!;
symlink 'regular-license', "$fixture/LICENSE" or die $!;
isnt($check->('--kind', 'mit'), 0, 'source license symlink refused');
unlink "$fixture/LICENSE" or die $!;
rename "$fixture/regular-license", "$fixture/LICENSE" or die $!;
my $archive = "$fixture/package.crate";
my $member = 'example-0.1.0/LICENSE';
my $package = sub {
    my $tar = Archive::Tar->new;
    for my $record (@_) { $tar->add_data(@$record) or die 'cannot add archive member'; }
    $tar->write($archive, 1) or die 'cannot write archive';
};
my $archive_check = sub {
    $check->('--kind', 'mit', '--archive', $archive, '--member', $member, @_);
};
$package->([$member, $mit], ['example-0.1.0/src/lib.rs', 'pub fn example() {}']);
is($archive_check->(), 0, 'prepared archive preserves exact source terms and notices');
my $good_archive = $read->($archive);
$write->($wrapped);
$package->([$member, $wrapped]);
is($archive_check->(), 0, 'CRLF source license remains exact inside the archive');
$write->($mit);
for my $record ([$member, $mit . "\n"], [$member, $mit =~ s/2024/2025/r], ['example-0.1.0/OTHER', $mit]) {
    $package->($record);
    isnt($archive_check->(), 0, 'missing or changed archived license refused');
}
$package->([$member, $mit], [$member, $mit]);
isnt($archive_check->(), 0, 'duplicate license entries refused');
for my $type (1, 2, 5) {
    $package->([$member, '', {type => $type, linkname => '../../outside'}]);
    isnt($archive_check->(), 0, 'license hardlink, symlink or directory refused');
}
$package->([$member, $mit], ['example-0.1.0/link', '', {type => 2, linkname => '../../outside'}]);
isnt($archive_check->(), 0, 'unselected archive symlink refused without extraction');
$package->([$member, $mit], ['../outside', 'must not extract']);
isnt($archive_check->(), 0, 'escaping archive path refused without extraction');
ok(!-e "$fixture/outside", 'archive inspection never extracts members');
$package->([$member, $mit]);
symlink 'package.crate', "$fixture/link.crate" or die $!;
isnt($check->('--kind', 'mit', '--archive', "$fixture/link.crate", '--member', $member), 0, 'archive symlink refused');
isnt($check->('--kind', 'mit', '--archive', $archive), 0, 'archive selection requires a member');
isnt($archive_check->('--member', '../LICENSE'), 0, 'escaping member selection refused');
open my $broken, '>', $archive or die $!;
binmode $broken;
print {$broken} substr($good_archive, 0, length($good_archive) - 4) or die $!;
close $broken or die $!;
isnt($archive_check->(), 0, 'complete-looking tar with truncated gzip trailer refused');
my $malformed = Archive::Tar->new;
$malformed->add_data($member, $mit);
$malformed->add_data('example-0.1.0/after-license', 'payload');
my $tar_bytes = $malformed->write;
my $next_header = 512 + 512 * int((length($mit) + 511) / 512);
substr($tar_bytes, $next_header, 1) = '!'; # Invalid checksum after a valid license.
gzip \$tar_bytes => $archive or die $GzipError;
isnt($archive_check->(), 0, 'tar error after a valid license cannot authorize the archive');
$write->($combined);
$package->([$member, $combined]);
is($check->('--kind', 'dragginz', '--prior-mit', '--archive', $archive, '--member', $member), 0,
    'complete preserved prior notice survives archive qualification');
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
