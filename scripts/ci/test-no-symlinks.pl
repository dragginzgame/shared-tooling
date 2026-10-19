#!/usr/bin/env perl
# Shared companions: scripts/ci/check-no-symlinks.pl
use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Copy qw(move);
use Test::More;

my $fixture = tempdir('no-symlinks.XXXXXX', TMPDIR => 1, CLEANUP => 0);
my $complete = 0;
END {
    my $status = $?;
    if (defined $fixture) {
        if ($complete && $status == 0 && Test::More->builder->is_passing) {
            my $errors;
            remove_tree($fixture, {error => \$errors});
            if (@$errors || -e $fixture || -l $fixture) {
                warn "Symlink fixture cleanup incomplete: $fixture\n";
                $status = 1;
            }
        } else {
            warn "Symlink fixtures retained: $fixture\n";
            $status ||= 1;
        }
    }
    $? = $status;
}
my $checker = "$FindBin::Bin/check-no-symlinks.pl";
my $repo = "$fixture/consumer space";
make_path("$repo/nested", "$fixture/outside", "$repo/.tools");
system('git', 'init', '-q', $repo) == 0 or die 'git init failed';
my $write = sub {
    open my $fh, '>', $_[0] or die $!;
    print {$fh} $_[1] or die $!;
    close $fh or die $!;
};
$write->("$repo/regular file", 'regular');
$write->("$repo/nested/input", 'inside');
$write->("$repo/.gitignore", "/.tools/\n");
$write->("$fixture/outside/input", 'untouched');
symlink "$fixture/outside", "$repo/.tools/host" or die $!;
system('git', '-C', $repo, 'add', '--', 'regular file', 'nested/input', '.gitignore') == 0 or die 'git add failed';
my $check = sub { system($^X, $checker, '--consumer', $repo); };
is($check->(), 0, 'regular source and ignored tool pointer pass');
for my $target ('regular file', 'missing', "$fixture/outside") {
    symlink $target, "$repo/untracked link" or die $!;
    isnt($check->(), 0, 'untracked regular, dangling and directory links refuse');
    unlink "$repo/untracked link" or die $!;
}
symlink 'missing', "$repo/index link" or die $!;
system('git', '-C', $repo, 'add', '--', 'index link') == 0 or die 'git add link failed';
unlink "$repo/index link" or die $!;
$write->("$repo/index link", 'regular working replacement');
isnt($check->(), 0, 'indexed symlink refuses even with regular working replacement');
{
    local $ENV{GIT_INDEX_FILE} = "$fixture/other-index";
    isnt($check->(), 0, 'inherited alternate index cannot hide the selected checkout index');
}
system('git', '-C', $repo, 'rm', '--cached', '-q', '-f', '--', 'index link') == 0 or die 'git rm failed';
move("$repo/nested", "$repo/retained") or die $!;
symlink "$fixture/outside", "$repo/nested" or die $!;
isnt($check->(), 0, 'symlinked tracked parent refuses');
open my $outside, '<', "$fixture/outside/input" or die $!;
is(do { local $/; <$outside> }, 'untouched', 'outside target preserved');
close $outside;
unlink "$repo/nested" or die $!;
move("$repo/retained", "$repo/nested") or die $!;
unlink "$repo/nested/input" or die $!;
is($check->(), 0, 'tracked deletion is allowed');
$write->("$repo/file\nname", 'newline file name');
is($check->(), 0, 'NUL-delimited inventory preserves unusual file names');
symlink 'missing', "$repo/link\nname" or die $!;
isnt($check->(), 0, 'newline link name still refuses');
unlink "$repo/link\nname" or die $!;
isnt(system($^X, $checker, '--consumer', "$repo/nested"), 0, 'subdirectory selection refuses');
# A plausible, complete inventory followed by failure must not pass admission.
my ($git) = grep { -f $_ && -x $_ } map { "$_/git" } split /:/, $ENV{PATH};
defined($git) or die 'Git unavailable';
make_path("$fixture/bin");
$write->("$fixture/bin/git", <<'GIT');
#!/usr/bin/env bash
set -euo pipefail
"$SYMLINK_REAL_GIT" "$@"
if [[ "$1" == ls-files ]]; then exit 37; fi
GIT
chmod 0755, "$fixture/bin/git" or die $!;
{
    local $ENV{PATH} = "$fixture/bin:$ENV{PATH}";
    local $ENV{SYMLINK_REAL_GIT} = $git;
    isnt($check->(), 0, 'failed Git observation cannot authenticate valid partial output');
}
is($check->(), 0, 'recovery after failures');
done_testing();
$complete = Test::More->builder->is_passing;
