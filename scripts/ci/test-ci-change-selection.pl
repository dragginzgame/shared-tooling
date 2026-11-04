#!/usr/bin/env perl
# Shared companions: scripts/ci/classify-ci-change.pl ci/docs-only-paths.txt
use strict; use warnings;
use Cwd qw(abs_path);
use FindBin;
use File::Temp qw(tempdir);
use Test::More;
my $script=abs_path("$FindBin::Bin/classify-ci-change.pl");
open my $policy_file, '<', "$FindBin::Bin/../../ci/docs-only-paths.txt" or die $!;
my $reviewed_policy = do { local $/; <$policy_file> };
close $policy_file or die $!;
my $fixture=tempdir('ci-change-selection.XXXXXX', TMPDIR=>1, CLEANUP=>0);
chdir $fixture or die $!;
local @ENV{qw(GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL)}=
 ('/dev/null',1,'Fixture','fixture@example.invalid','Fixture','fixture@example.invalid');
delete @ENV{qw(GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES)};
sub run {system(@_)==0 or die "command failed: @_\n"}
sub capture {open my $f,'-|',@_ or die $!; local $/; my $v=<$f>; close $f or die "capture failed\n"; $v =~ s/\n\z//; return $v;}
sub write_file {my ($p,$s)=@_; open my $f,'>',$p or die $!; print $f $s; close $f;}
sub commit {run('git','add','--all'); run('git','commit','-qm','fixture'); return capture('git','rev-parse','HEAD');}
run('git','init','-q'); run('git','config','commit.gpgsign','false');
write_file('policy.txt',"guide.md\nother.md\nspace name.md\n");
write_file('guide.md',"guide\n"); write_file('code.rs',"code\n");
my $base=commit();
sub scope {my ($b,$h,$event,$ref,@options)=@_; return capture($^X,$script,'--base',$b,'--head',$h,'--event',$event//'push','--ref',$ref//'refs/heads/main','--policy','policy.txt',@options);}
sub restore_base {run('git','reset','--hard','-q',$base); run('git','clean','-fdq');}
write_file('guide.md',"updated\n"); my $docs=commit();
is(scope($base,$docs),'docs','prose change');
is(scope($base,$docs,'pull_request'),'docs','PR merge-base comparison');
is(scope($base,$docs,'push','refs/tags/v1'),'full','tags never shortcut');
is(scope($base,$docs,'release'),'full','release never shortcut');
is(scope('0'x40,$docs),'full','missing history');
is(scope($base,$base),'full','empty comparison');
restore_base(); write_file('code.rs',"changed\n"); write_file('guide.md',"updated\n"); my $mixed=commit();
is(scope($base,$mixed),'full','mixed change');
is(scope($docs,$mixed),'full','non-ancestor push');
is(scope($docs,$mixed,'pull_request'),'full','diverged PR detects code since merge base');
is(scope($mixed,$docs,'pull_request'),'docs','base branch changes are not attributed to the PR');
restore_base(); write_file('unknown.md',"new\n"); is(scope($base,commit()),'full','unknown Markdown');
restore_base(); write_file('policy.txt',"guide.md\nother.md\n"); is(scope($base,commit()),'full','policy edit');
restore_base(); run('git','mv','code.rs','other.md'); is(scope($base,commit()),'full','rename from code');
restore_base(); run('git','mv','guide.md','other.md'); is(scope($base,commit()),'docs','rename between admitted prose paths');
restore_base(); unlink 'guide.md' or die $!; is(scope($base,commit()),'docs','prose deletion');
restore_base(); chmod 0755,'guide.md' or die $!; is(scope($base,commit()),'full','executable Markdown');
restore_base(); unlink 'guide.md' or die $!; symlink 'code.rs','guide.md' or die $!; is(scope($base,commit()),'full','symlink');
restore_base(); write_file("bad\nname.md","x"); is(scope($base,commit()),'full','newline path');
restore_base(); write_file('space name.md',"new\n"); is(scope($base,commit()),'docs','ordinary spaces');
restore_base(); write_file('policy.txt',"../guide.md\n"); my $bad=commit(); write_file('guide.md',"changed\n"); is(scope($bad,commit()),'full','invalid unchanged policy');
restore_base(); unlink 'policy.txt' or die $!; my $missing=commit(); write_file('guide.md',"changed\n"); is(scope($missing,commit()),'full','absent policy');
restore_base(); chmod 0755,'policy.txt' or die $!; my $executable=commit(); write_file('guide.md',"changed\n"); is(scope($executable,commit()),'full','executable policy');
restore_base(); write_file('policy.txt',"guide.md\nguide.md\n"); my $duplicate=commit(); write_file('guide.md',"changed\n"); is(scope($duplicate,commit()),'full','duplicate policy entries');
restore_base(); write_file('policy.txt',"# No eligible documents\n"); my $empty=commit(); write_file('guide.md',"changed\n"); is(scope($empty,commit()),'full','empty policy');
restore_base();
run('git','update-index','--add','--cacheinfo',"160000,$base,dependency");
run('git','commit','-qm','fixture gitlink');
my $submodule_base=capture('git','rev-parse','HEAD');
write_file('guide.md',"updated\n"); run('git','add','guide.md');
run('git','update-index','--cacheinfo',"160000,$docs,dependency");
run('git','commit','-qm','fixture gitlink update');
my $submodule_head=capture('git','rev-parse','HEAD');
run('git','config','diff.ignoreSubmodules','all');
is(scope($submodule_base,$submodule_head),'full','Git settings cannot hide changed submodule identities');
restore_base();
write_file('policy.txt', $reviewed_policy);
mkdir 'rules' or die $!;
write_file('rules/rpc-budgets.md', "RPC policy\n");
my $reviewed_base=commit();
write_file('rules/rpc-budgets.md', "Clarified RPC policy\n");
my $reviewed_docs=commit();
is(scope($reviewed_base,$reviewed_docs),'docs','reviewed RPC guide uses prose qualification');
write_file('README.md', "Developer overview\n");
mkdir 'docs' or die $!;
write_file('docs/make-interface.md', "Developer command guide\n");
my $reviewed_guides=commit();
is(scope($reviewed_docs,$reviewed_guides),'docs','reviewed README and developer guide use prose qualification');
write_file('code.rs', "changed implementation\n");
is(scope($reviewed_docs,commit()),'full','reviewed guides plus code keep full qualification');
run('git','reset','--hard','-q',$reviewed_docs);
write_file('VERSION', "0.0.1\n");
is(scope($reviewed_base,commit()),'full','RPC guide plus release version keeps full qualification');
run('git','reset','--hard','-q',$reviewed_docs);
mkdir 'scripts' or die $!;
mkdir 'scripts/distribution' or die $!;
write_file('scripts/distribution/governance-files.txt', "rules/rpc-budgets.md\n");
is(scope($reviewed_base,commit()),'full','RPC guide plus snapshot catalog keeps full qualification');

restore_base();
write_file('policy.txt', "guide.md\nCHANGELOG.md\n");
write_file('VERSION', "0.1.0\n");
write_file('CHANGELOG.md', "# Changes\n\n## [0.1.0] - 2026-11-01\n\nInitial release.\n");
my $version_base=commit();
sub restore_version_base {run('git','reset','--hard','-q',$version_base); run('git','clean','-fdq');}
sub version_scope {my ($b,$h,$event,$ref)=@_; return scope($b,$h,$event,$ref,'--allow-version-bump');}
my $version_notes="# Changes\n\n## [0.1.1] - Unreleased\n\nClarified rules.\n\n## [0.1.0] - 2026-11-01\n\nInitial release.\n";
sub bump {
    write_file('VERSION', "0.1.1\n");
    write_file('CHANGELOG.md', $version_notes);
    write_file('guide.md', "Clarified guide\n");
}
bump(); my $version_head=commit();
is(scope($version_base,$version_head),'full','version exception requires opt-in');
is(version_scope($version_base,$version_head),'docs','valid prose and version bump');
is(version_scope($version_base,$version_head,'pull_request'),'docs','valid PR version bump');
is(version_scope($version_base,$version_head,'push','refs/tags/v0.1.1'),'full','version opt-in does not admit tags');
write_file('VERSION', "broken working tree\n");
is(version_scope($version_base,$version_head),'docs','classification reads committed metadata');
restore_version_base(); bump(); write_file('code.rs', "changed\n");
is(version_scope($version_base,commit()),'full','code plus valid bump remains full');
restore_version_base(); bump(); write_file('unknown.md', "unreviewed\n");
is(version_scope($version_base,commit()),'full','unknown prose plus bump remains full');
for my $bad_version ("garbage\n", "0.01.1\n", "0.1.1-beta.1\n", "0.1.1\nextra\n", "0.1.2\n") {
    restore_version_base(); bump(); write_file('VERSION', $bad_version);
    is(version_scope($version_base,commit()),'full',"invalid or mismatched version: $bad_version");
}
restore_version_base(); bump(); write_file('VERSION', "0.0.9\n");
write_file('CHANGELOG.md', "# Changes\n\n## [0.0.9]\n\nRollback\n");
is(version_scope($version_base,commit()),'full','matching version rollback remains full');
restore_version_base(); write_file('VERSION', "0.1.1\n");
is(version_scope($version_base,commit()),'full','version-only change remains full');
restore_version_base(); bump(); unlink 'VERSION' or die $!;
is(version_scope($version_base,commit()),'full','deleted version remains full');
restore_version_base(); bump(); chmod 0755, 'VERSION' or die $!;
is(version_scope($version_base,commit()),'full','executable version remains full');
restore_version_base(); bump(); unlink 'VERSION' or die $!; symlink 'guide.md', 'VERSION' or die $!;
is(version_scope($version_base,commit()),'full','symlink version remains full');
restore_version_base(); bump(); unlink 'CHANGELOG.md' or die $!;
is(version_scope($version_base,commit()),'full','deleted changelog remains full');
restore_version_base(); bump();
write_file('CHANGELOG.md', "## [0.1.1] - Unreleased\n");
is(version_scope($version_base,commit()),'full','pending version without history remains full');
restore_version_base(); bump();
write_file('CHANGELOG.md', $version_notes . "\n## [0.1.1]\nDuplicate\n");
is(version_scope($version_base,commit()),'full','duplicate top version remains full');
restore_version_base(); write_file('VERSION', "invalid\n"); my $invalid_base=commit();
bump(); is(version_scope($invalid_base,commit()),'full','repair of invalid base requires full CI');
restore_version_base(); unlink 'VERSION' or die $!; my $absent_base=commit();
bump(); is(version_scope($absent_base,commit()),'full','introducing VERSION requires full CI');
restore_version_base(); bump();
is(version_scope($version_base,commit()),'docs','valid input recovers after rejected cases');
done_testing();
# Retain failures; remove only this fixture after a successful assertion set.
if (Test::More->builder->is_passing) { chdir '/'; require File::Path; File::Path::remove_tree($fixture); }
else { warn "Retained fixture: $fixture\n"; }
