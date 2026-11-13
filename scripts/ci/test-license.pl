#!/usr/bin/env perl
# Shared companions: scripts/ci/check-license.pl LICENSE.md
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use Test::More;
use Archive::Tar;

my $root = "$FindBin::Bin/../..";
my $fixture = tempdir('license-check.XXXXXX', TMPDIR => 1, CLEANUP => 0);
my $complete = 0;
END {
    my $status = $?;
    if ($complete && $status == 0 && Test::More->builder->is_passing) {
        my $errors;
        remove_tree($fixture, {error => \$errors});
        $status = 1 if @$errors || -e $fixture || -l $fixture;
    } else {
        warn "Licence fixtures retained: $fixture\n";
        $status ||= 1;
    }
    $? = $status;
}
sub read_file {
    open my $fh, '<', $_[0] or die $!;
    binmode $fh;
    local $/;
    my $text = <$fh>;
    close $fh or die $!;
    return $text;
}
sub write_file {
    open my $fh, '>', $_[0] or die $!;
    binmode $fh;
    print {$fh} $_[1];
    close $fh or die $!;
}
my $source = "$fixture/LICENSE.md";
my $canonical = read_file("$root/LICENSE.md");
write_file($source, $canonical);
my $checker = "$root/scripts/ci/check-license.pl";
my $check = sub { system($^X, $checker, '--file', $source, @_); };

is($check->(), 0, 'exact adopted TSNL-1.0 accepted');
for my $changed (
    $canonical =~ s/TSNL-1\.0/TSNL-9.9/r,
    $canonical =~ s/one hundred percent \(100%\)/zero percent (0%)/r,
    $canonical . "\nAdditional permission.\n",
    $canonical =~ s/\n/\r\n/gr,
) {
    write_file($source, $changed);
    isnt($check->(), 0, 'changed licence rejected');
}
isnt(system($^X, $checker, '--file', "$fixture/missing"), 0, 'missing file rejected');
write_file($source, $canonical);
rename $source, "$fixture/regular-license" or die $!;
symlink 'regular-license', $source or die $!;
isnt($check->(), 0, 'source licence symlink rejected');
unlink $source or die $!;
rename "$fixture/regular-license", $source or die $!;

my $archive = "$fixture/package.crate";
my $member = 'example-0.1.0/LICENSE.md';
my $package = sub {
    my $tar = Archive::Tar->new;
    for my $record (@_) { $tar->add_data(@$record) or die 'cannot add archive member'; }
    $tar->write($archive, 1) or die 'cannot write archive';
};
my $archive_check = sub { $check->('--archive', $archive, '--member', $member, @_); };
$package->([$member, $canonical], ['example-0.1.0/src/lib.rs', 'pub fn example() {}']);
is($archive_check->(), 0, 'package preserves exact adopted licence');
my $good_archive = read_file($archive);
for my $record ([$member, $canonical . "\n"], ['example-0.1.0/OTHER', $canonical]) {
    $package->($record);
    isnt($archive_check->(), 0, 'missing or changed archive licence rejected');
}
$package->([$member, $canonical], [$member, $canonical]);
isnt($archive_check->(), 0, 'duplicate archive licence rejected');
$package->([$member, '', {type => 2, linkname => '../../outside'}]);
isnt($archive_check->(), 0, 'nonregular archive licence rejected');
$package->([$member, $canonical], ['../outside', 'must not extract']);
isnt($archive_check->(), 0, 'escaping archive member rejected');
ok(!-e "$fixture/outside", 'archive inspection never extracts members');
$package->([$member, $canonical]);
symlink 'package.crate', "$fixture/link.crate" or die $!;
isnt($check->('--archive', "$fixture/link.crate", '--member', $member), 0, 'archive symlink rejected');
isnt($check->('--archive', $archive), 0, 'archive selection requires a member');
isnt($archive_check->('--member', '../LICENSE.md'), 0, 'escaping selection rejected');
write_file($archive, substr($good_archive, 0, length($good_archive) - 4));
isnt($archive_check->(), 0, 'truncated gzip rejected');

my $original_checker = $checker;
for my $layout ('scripts/ci', 'vendor/toko-tooling/scripts/ci') {
    subtest "relocated $layout" => sub {
        my $repository = "$fixture/snapshot-$layout";
        make_path("$repository/$layout");
        $checker = "$repository/$layout/check-license.pl";
        copy($original_checker, $checker) or die $!;
        my $document = "$repository/LICENSE.md";
        write_file($document, $canonical);
        write_file($source, $canonical);
        # A vendor-local document must never override or rescue the root file.
        write_file("$repository/vendor/toko-tooling/LICENSE.md", 'stale vendor copy')
            if $layout =~ m{\Avendor/};
        is($check->(), 0, 'resolves root document independently of caller cwd');
        $package->([$member, $canonical]);
        is($archive_check->(), 0, 'archive matches root document');
        $package->([$member, $canonical . "\n"]);
        isnt($archive_check->(), 0, 'changed archive rejected');
        write_file($document, 'malformed root');
        isnt($check->(), 0, 'malformed root rejected');
        unlink $document or die $!;
        write_file("$repository/vendor/toko-tooling/LICENSE.md", $canonical)
            if $layout =~ m{\Avendor/};
        isnt($check->(), 0, 'missing root rejected without fallback');
        symlink $source, $document or die $!;
        isnt($check->(), 0, 'root symlink rejected');
    };
}
done_testing();
$complete = Test::More->builder->is_passing;
