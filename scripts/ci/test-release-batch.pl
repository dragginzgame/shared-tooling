#!/usr/bin/env perl
# Shared companions: scripts/ci/run-release-batch.pl scripts/ci/prepare-script-fixture.sh scripts/ci/test-release-timing.pl
use strict;
use warnings;
use FindBin qw($RealBin);
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use Cwd qw(abs_path);
use JSON::PP;
use Test::More;
my $scratch="$RealBin/../../target/tmp"; make_path($scratch);
my $fixture=tempdir('release-batch.XXXXXXXX',DIR=>$scratch,CLEANUP=>0);
$fixture=abs_path($fixture);
my $root="$fixture/development";
my $remote="$fixture/remote.git";
sub run {system @_; $?==0 or die "command failed: @_\n";}
sub output {open my $f,'-|',@_ or die $!;local $/;my $s=<$f>//'';close $f or die "command failed: @_";$s =~ s/\n\z//;return $s;}
sub write_file {open my $f,'>',$_[0] or die $!;print {$f} $_[1];close $f or die $!;}
note(output($^X,"$RealBin/test-release-timing.pl"));
pass('timing clock, failure, interruption and readback regression');
# File::Temp can generate underscores. Force one so resume qualification cannot
# pass merely because a random batch happened to use alphanumeric characters.
make_path("$fixture/perl");
write_file("$fixture/perl/ReleaseBatchUnderscore.pm",<<'MODULE');
package ReleaseBatchUnderscore;
use strict;
use warnings;
use File::Temp ();
my $original=\&File::Temp::tempdir;
{
    no warnings 'redefine';
    *File::Temp::tempdir=sub {
        my @args=@_;
        $args[0]='batch-_XXXXXXX' if @args && $args[0] eq 'batch-XXXXXXXX';
        return $original->(@args);
    };
}
1;
MODULE
local $ENV{PERL5LIB}="$fixture/perl";
local $ENV{PERL5OPT}='-MReleaseBatchUnderscore';
run('git','init','--quiet','--bare',$remote);
run('git','init','--quiet','-b','delivery',$root);
run('git','-C',$root,'config','user.name','Release fixture');
run('git','-C',$root,'config','user.email','fixture@example.invalid');
run('git','-C',$root,'remote','add','selected',$remote);
write_file("$root/.gitignore","/target/\n");
write_file("$root/Cargo.lock","original-lock\n");
write_file("$root/Makefile",<<'MAKE');
.PHONY: release-version release-patch publish setup-candidate
setup-candidate:
	@test '$(RELEASE_REMOTE)' = selected && test '$(RELEASE_BRANCH)' = delivery
	@test '$(RELEASE_SOURCE)' = "$$(git rev-parse HEAD)"
	@test '$(RELEASE_SETUP_MODE)' = prepare
	@if [ "$${BAD_SETUP:-}" = yes ]; then printf 'bad-setup\n' >> Cargo.lock; fi
	@mkdir -p target
	@touch target/setup
release-version:
	@test -f target/setup
	@echo 0.1.0
release-patch:
	@test "$$(cat Cargo.lock)" = original-lock
	@if [ "$(RELEASE_GROUP)" = alpha ]; then printf 'deferred-cargo-update\n' > "$$DEVELOPMENT_ROOT/Cargo.lock"; fi
	@test "$$(cat Cargo.lock)" = original-lock
	@printf '%s\n' '$(RELEASE_GROUP)' >> delivered
	@git add delivered
	@git commit -qm 'Release $(RELEASE_GROUP)'
	@git tag -a '$(RELEASE_GROUP)-v0.1.1' -m release
	@git push --quiet --atomic '$(RELEASE_REMOTE)' 'HEAD:refs/heads/$(RELEASE_BRANCH)' 'refs/tags/$(RELEASE_GROUP)-v0.1.1'
publish:
	@test "$$(cat Cargo.lock)" = original-lock
	@test '$(RELEASE_REMOTE)' = selected && test '$(RELEASE_BRANCH)' = delivery
	@test '$(RELEASE_VERSION)' = 0.1.1 && test '$(RELEASE_KIND)' = patch
	@test '$(RELEASE_COMMIT)' = "$$(git rev-parse HEAD)"
	@test '$(RELEASE_SOURCE)' = "$$(git rev-parse HEAD^)"
	@printf '%s\n' '$(RELEASE_GROUP)' >> "$$PUBLICATION_TRACE"
MAKE
run('git','-C',$root,'add','.');run('git','-C',$root,'commit','-qm','Fixture source');
run('git','-C',$root,'push','--quiet','selected','delivery');
my $base=output('git','-C',$root,'rev-parse','HEAD');
$ENV{DEVELOPMENT_ROOT}=$root; $ENV{PUBLICATION_TRACE}="$fixture/publications";
run($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--groups','alpha,beta','--publish-target','publish',
    '--setup-target','setup-candidate','--remote','selected','--branch','delivery');
is(output('git','-C',$root,'rev-parse','HEAD'),$base,'normal branch remains intact');
open my $f,'<',"$root/Cargo.lock" or die $!;is(<$f>,"deferred-cargo-update\n",'concurrent lock edit preserved');close $f;
is(output('git','--git-dir',$remote,'show','delivery:Cargo.lock'),'original-lock','delivered graph remains frozen across groups');
is(output('git','--git-dir',$remote,'show','delivery:delivered'),"alpha\nbeta",'both groups delivered in order with saved publication context');
open $f,'<',"$fixture/publications" or die $!;{local $/;is(<$f>,"alpha\nbeta\n",'both publications use the candidate');}close $f;
my @intents=glob("$root/.git/release-state/frozen/batch-*/intent.json");is(scalar @intents,1,'one durable batch');
open $f,'<',$intents[0] or die $!;my $record;{local $/;$record=decode_json(<$f>);}close $f;
is($record->{phase},'complete','completion retained outside target');
my ($id)=$intents[0] =~ m{/(batch-[^/]+)/intent.json};
is(index($id,'batch-_'),0,'resume fixture contains a generated underscore');
run($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--resume',$id);
open $f,'<',"$fixture/publications" or die $!;{local $/;is(<$f>,"alpha\nbeta\n",'complete resume never republishes');}close $f;
my $status=system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--groups','gamma','--branch','delivery','--remote','selected');
ok($status!=0,'new batch cannot silently absorb deferred uncommitted update');
# Durable Git objects include release commits; disposable worktree loss must not
# erase the only record of delivery.
is(output('git','--git-dir',"$root/.git/release-state/frozen/$id/repository.git",'show','HEAD:delivered'),"alpha\nbeta",'candidate commits remain in durable Git storage');
my $export="$fixture/export";make_path($export);
run('bash',"$RealBin/prepare-script-fixture.sh","$RealBin/../..",$export,'scripts/ci/run-release-batch.pl');
ok(-f "$export/scripts/ci/validate-release-inputs.pl",'version admission exported');
my $refused=system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--resume',$id,'--delivery','pr');
ok($refused!=0,'PR delivery cannot silently become direct delivery');
$record->{phase}='publishing'; $record->{index}=1;
write_file($intents[0],encode_json($record));
ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--resume',$id)!=0,
    'uncertain publication refuses automatic redispatch');
run($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--resume',$id,'--publication-result','published');
is(output('cat',"$fixture/publications"),"alpha\nbeta",'verified publication reconciliation does not upload again');
my $completed=decode_json(output('cat',$intents[0]));
write_file($intents[0],encode_json({%$completed,schema=>1}));
ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--resume',$id)!=0,
    'pre-cut batch journal requires its original tooling');
my $missing_identity={%$completed,phase=>'publish',index=>1};
delete $missing_identity->{release_commit};
write_file($intents[0],encode_json($missing_identity));
ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--resume',$id)!=0,
    'publication cannot infer a missing saved identity from HEAD');
is(output('cat',"$fixture/publications"),"alpha\nbeta",'invalid recovery does not repeat publication');
my $bad={%$completed,index=>0};
write_file($intents[0],encode_json($bad));
ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--resume',$id)!=0,
    'complete phase with unfinished groups refuses instead of looping');
write_file($intents[0],encode_json({%$completed,phase=>'publish'}));
ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--resume',$id)!=0,
    'publication past final group refuses instead of silently completing');
write_file($intents[0],encode_json($completed));
my $before_status=output('cat',$intents[0]);
run($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--status',$id);
is(output('cat',$intents[0]),$before_status,'status does not rewrite recovery intent');
ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--reconcile',$id)!=0,'dirty normal checkout refuses reconciliation');
is(output('cat',"$root/Cargo.lock"),'deferred-cargo-update','refused reconciliation preserves deferred lock');
# This fixture's deferred edit has been asserted; explicitly clear it so the
# reconciliation path can be tested, never applying this to real user work.
run('git','-C',$root,'restore','--','Cargo.lock');
write_file("$root/Cargo.lock","committed-deferred-update\n");
run('git','-C',$root,'add','Cargo.lock');run('git','-C',$root,'commit','-qm','Deferred update fixture');
my $deferred=output('git','-C',$root,'rev-parse','HEAD');
ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--reconcile',$id)!=0,'diverged normal branch refuses automatic merging');
is(output('git','-C',$root,'rev-parse','HEAD'),$deferred,'failed reconciliation preserves deferred commit');
run('git','-C',$root,'reset','--hard',$base);
run($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--reconcile',$id);
is(output('git','-C',$root,'rev-parse','HEAD'),$completed->{commit},'clean reconciliation fast-forwards to delivered source');
my $candidate="$root/target/release-frozen/$id";
write_file("$candidate/pending-work",'preserve');
ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--retire',$id)!=0,'retirement refuses unique candidate work');
ok(-f "$candidate/pending-work",'refused retirement preserves candidate work');
unlink "$candidate/pending-work" or die $!;
run('git','-C',$candidate,'update-ref','refs/private/keep',$completed->{commit});
ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--retire',$id)!=0,'retirement refuses additional candidate refs');
run('git','-C',$candidate,'update-ref','-d','refs/private/keep');
run($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--retire',$id);
ok(!-e $candidate && !-e "$root/.git/release-state/frozen/$id",'explicit retirement removes only completed batch storage');
is(output('git','-C',$root,'tag','--list'),"alpha-v0.1.1\nbeta-v0.1.1",'retirement retains release tags in normal repository');
{
    local $ENV{BAD_SETUP}='yes';
    ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--groups','gamma',
        '--setup-target','setup-candidate','--remote','selected','--branch','delivery')!=0,
        'candidate setup may prepare tools but cannot mutate lock inputs');
}
is(output('cat',"$root/Cargo.lock"),'original-lock','bad candidate setup cannot change the normal lock');

# Exercise the actual shared Make entrypoints and Git release state machine.
my $real="$fixture/real";
run('git','init','--quiet','-b','main',$real);
run('git','-C',$real,'config','user.name','Release fixture');
run('git','-C',$real,'config','user.email','fixture@example.invalid');
run('git','init','--quiet','--bare',"$fixture/real-remote.git");
run('git','-C',$real,'remote','add','origin',"$fixture/real-remote.git");
run('bash',"$RealBin/prepare-script-fixture.sh","$RealBin/../..",$real,'make/release.mk');
make_path("$real/ci");
write_file("$real/.gitignore","/target/\n");
write_file("$real/Cargo.toml",<<'TOML');
[workspace]
members = ["alpha", "beta"]
resolver = "2"
[workspace.dependencies]
alpha = { path = "alpha", version = "0.1.0" }
beta = { path = "beta", version = "0.1.0" }
TOML
my @policy;
for my $group (qw(alpha beta)) {
    make_path("$real/$group/src");
    write_file("$real/$group/src/lib.rs",'');
    write_file("$real/$group/Cargo.toml","[package]\nname = \"$group\"\nversion = \"0.1.0\"\nedition = \"2021\"\n");
    write_file("$real/$group/CHANGELOG.md","# Changelog\n\n## [0.1.1] - Unreleased\n\n- Fixture.\n");
    push @policy,{name=>$group,primary=>$group,version=>'package',members=>[$group],changelog=>"$group/CHANGELOG.md",dependencies=>[$group]};
}
write_file("$real/ci/cargo-release-groups.json",encode_json({schema=>1,groups=>\@policy}));
write_file("$real/Makefile",<<'MAKE');
TOKO_TOOLING_ROOT := $(CURDIR)
RELEASE_GROUPS := alpha,beta
RELEASE_SETUP_TARGET := setup-candidate
include make/release.mk
setup-candidate:
	@mkdir -p target
	@touch target/setup
	@printf '%s %s\n' '$(RELEASE_GROUP)' '$(RELEASE_SETUP_MODE)' >> "$$SETUP_TRACE"
release-version:
	@test -f target/setup
	@sed -n 's/^version = "\(.*\)"/\1/p' $(RELEASE_GROUP)/Cargo.toml
release-verify:
	@! grep -q deferred Cargo.lock
	@if [ "$(RELEASE_GROUP)" = alpha ]; then printf '\n# deferred update\n' >> "$$DEVELOPMENT_ROOT/Cargo.lock"; fi
	@if [ "$(RELEASE_GROUP)" = beta ] && [ -f "$$FAIL_ONCE" ]; then rm "$$FAIL_ONCE"; exit 1; fi
release-prepare-version:
	@perl -pi -e 's/0\.1\.0/0.1.1/g' $(RELEASE_GROUP)/Cargo.toml
	@perl -pi -e 's/0\.1\.0/0.1.1/ if /^$(RELEASE_GROUP) = /' Cargo.toml
	@cargo generate-lockfile --offline
release-files:
	@bash scripts/ci/cargo-release-group.sh files $(RELEASE_GROUP)
release-preflight release-prepared-check release-commit-check release-committed-check release-tagged-check release-push-check:
	@:
MAKE
run('cargo','generate-lockfile','--offline','--manifest-path',"$real/Cargo.toml");
run('git','-C',$real,'add','.');run('git','-C',$real,'commit','-qm','Real runner fixture');
run('git','-C',$real,'push','--quiet','origin','main');
$ENV{DEVELOPMENT_ROOT}=$real;
$ENV{SETUP_TRACE}="$fixture/setup-trace";
$ENV{FAIL_ONCE}="$fixture/fail-once"; write_file($ENV{FAIL_ONCE},'fail');
ok(system('make','--no-print-directory','-C',$real,'release-patch')!=0,'real second-group gate failure stops delivery');
is(output('git','--git-dir',"$fixture/real-remote.git",'tag','--list'),'alpha-v0.1.1','failed second group does not repeat or undo first delivery');
my @real_intents=glob("$real/.git/release-state/frozen/batch-*/intent.json");
my ($real_id)=$real_intents[0] =~ m{/(batch-[^/]+)/intent.json};
run('make','--no-print-directory','-C',$real,'release-batch-status',"BATCH=$real_id");
run('make','--no-print-directory','-C',$real,'release-batch-resume',"BATCH=$real_id");
is(output('git','--git-dir',"$fixture/real-remote.git",'tag','--list'),"alpha-v0.1.1\nbeta-v0.1.1",'real runner releases both groups through ordinary Make target');
like(output('git','-C',$real,'diff','--','Cargo.lock'),qr/deferred update/,'real runner preserves concurrent normal lock edit');
is(output('cat',$ENV{SETUP_TRACE}),"alpha prepare\nbeta prepare\nbeta check",'recovery selects offline setup admission rather than fresh preparation');
my $timing_path="$real/.git/release-state/frozen/$real_id/timings.jsonl";
my $timing_before=output('cat',$timing_path);
my $timing_rows=decode_json(output('make','--no-print-directory','-s','-C',$real,'release-batch-timings',"BATCH=$real_id"));
is(output('cat',$timing_path),$timing_before,'collector does not rewrite timings or rerun release');
my @validation=grep {$_->{phase} eq 'release-validate'} @$timing_rows;
is(scalar(@validation),3,'real runner retains original failed validation and resumed execution');
is_deeply([map {$_->{result}} @validation],[qw(passed failed passed)],'phase results follow actual execution');
isnt($validation[1]{attempt},$validation[2]{attempt},'resume has a new attempt identity');
is(scalar(grep {$_->{phase} eq 'release-push' && $_->{result} eq 'passed'} @$timing_rows),2,'both real Git delivery boundaries observed');
# Exercise default dispatch without Git or registry effects. The real runner's
# multi-group/capture behavior is qualified above; these sentinels select it.
my $routing="$fixture/routing";make_path($routing);
run('git','init','--quiet',$routing);
run('bash',"$RealBin/prepare-script-fixture.sh","$RealBin/../..",$routing,'make/release.mk');
write_file("$routing/Makefile","TOKO_TOOLING_ROOT := \$(CURDIR)\ninclude make/release.mk\n");
write_file("$routing/scripts/ci/run-release-batch.pl",'print "batch:@ARGV\n";');
write_file("$routing/scripts/ci/run-release.sh",'printf "standard:%s\\n" "$*"');
for my $kind (qw(patch minor major)) {
    like(output('make','--no-print-directory','-C',$routing,"release-$kind",'RELEASE_GROUP=engine'),
        qr/batch:.*--groups engine --kind $kind /,"$kind captures selected group by default");
}
like(output('make','--no-print-directory','-C',$routing,'release-patch','RELEASE_GROUPS=types,runtime'),
    qr/batch:.*--groups types,runtime /,'explicit multi-group roster reaches the batch runner');
like(output('make','--no-print-directory','-C',$routing,'release-patch'),
    qr/standard:patch origin main/,'ungrouped release retains ordinary runner');
like(output('make','--no-print-directory','-C',$routing,'release-patch','RELEASE_GROUP=engine','RELEASE_BATCH_ACTIVE=1'),
    qr/standard:patch origin main/,'captured group invokes standard runner without recursive capture');
ok(system('make','--no-print-directory','-C',$routing,'release-patch','RELEASE_GROUP=engine','RELEASE_GROUPS=')!=0,
    'clearing roster cannot silently bypass selected-group capture');
ok(system('make','--no-print-directory','-C',$routing,'release-patch','RELEASE_GROUP=engine',
    'RELEASE_FROZEN_GROUPS=engine,wire')!=0,'retired roster refuses rather than silently releasing only one group');
{
    local $ENV{FROZEN_RELEASE_ACTIVE}=1;
    ok(system($^X,"$RealBin/run-release-batch.pl",'--root',$root,'--groups','engine')!=0,
        'retired active marker is refused at the standalone entrypoint');
}
done_testing();
if (Test::More->builder->is_passing) {remove_tree($fixture)} else {warn "fixture retained: $fixture\n";}
