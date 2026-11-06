#!/usr/bin/env perl
# Shared companions: scripts/ci/run-frozen-release.pl scripts/ci/prepare-script-fixture.sh
use strict;
use warnings;
use FindBin qw($RealBin);
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use Cwd qw(abs_path);
use JSON::PP;
use Test::More;
my $scratch="$RealBin/../../target/tmp"; make_path($scratch);
my $fixture=tempdir('frozen-release.XXXXXXXX',DIR=>$scratch,CLEANUP=>0);
$fixture=abs_path($fixture);
my $root="$fixture/development";
my $remote="$fixture/remote.git";
sub run {system @_; $?==0 or die "command failed: @_\n";}
sub output {open my $f,'-|',@_ or die $!;local $/;my $s=<$f>//'';close $f or die "command failed: @_";$s =~ s/\n\z//;return $s;}
sub write_file {open my $f,'>',$_[0] or die $!;print {$f} $_[1];close $f or die $!;}
# File::Temp can generate underscores. Force one so resume qualification cannot
# pass merely because a random batch happened to use alphanumeric characters.
make_path("$fixture/perl");
write_file("$fixture/perl/FrozenBatchUnderscore.pm",<<'MODULE');
package FrozenBatchUnderscore;
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
local $ENV{PERL5OPT}='-MFrozenBatchUnderscore';
run('git','init','--quiet','--bare',$remote);
run('git','init','--quiet','-b','main',$root);
run('git','-C',$root,'config','user.name','Release fixture');
run('git','-C',$root,'config','user.email','fixture@example.invalid');
run('git','-C',$root,'remote','add','origin',$remote);
write_file("$root/.gitignore","/target/\n");
write_file("$root/Cargo.lock","original-lock\n");
write_file("$root/Makefile",<<'MAKE');
.PHONY: release-version release-patch publish
release-version:
	@echo 0.1.0
release-patch:
	@test "$$(cat Cargo.lock)" = original-lock
	@if [ "$(RELEASE_GROUP)" = alpha ]; then printf 'deferred-cargo-update\n' > "$$DEVELOPMENT_ROOT/Cargo.lock"; fi
	@test "$$(cat Cargo.lock)" = original-lock
	@printf '%s\n' '$(RELEASE_GROUP)' >> delivered
	@git add delivered
	@git commit -qm 'Release $(RELEASE_GROUP)'
	@git tag -a '$(RELEASE_GROUP)-v0.1.1' -m release
	@git push --quiet --atomic origin HEAD:refs/heads/main 'refs/tags/$(RELEASE_GROUP)-v0.1.1'
publish:
	@test "$$(cat Cargo.lock)" = original-lock
	@printf '%s\n' '$(RELEASE_GROUP)' >> "$$PUBLICATION_TRACE"
MAKE
run('git','-C',$root,'add','.');run('git','-C',$root,'commit','-qm','Fixture source');
run('git','-C',$root,'push','--quiet','origin','main');
my $base=output('git','-C',$root,'rev-parse','HEAD');
$ENV{DEVELOPMENT_ROOT}=$root; $ENV{PUBLICATION_TRACE}="$fixture/publications";
run($^X,"$RealBin/run-frozen-release.pl",'--root',$root,'--groups','alpha,beta','--publish-target','publish');
is(output('git','-C',$root,'rev-parse','HEAD'),$base,'normal branch remains intact');
open my $f,'<',"$root/Cargo.lock" or die $!;is(<$f>,"deferred-cargo-update\n",'concurrent lock edit preserved');close $f;
is(output('git','--git-dir',$remote,'show','main:Cargo.lock'),'original-lock','delivered graph remains frozen across groups');
is(output('git','--git-dir',$remote,'show','main:delivered'),"alpha\nbeta",'both groups delivered in order');
open $f,'<',"$fixture/publications" or die $!;{local $/;is(<$f>,"alpha\nbeta\n",'both publications use the candidate');}close $f;
my @intents=glob("$root/.git/release-state/frozen/batch-*/intent.json");is(scalar @intents,1,'one durable batch');
open $f,'<',$intents[0] or die $!;my $record;{local $/;$record=decode_json(<$f>);}close $f;
is($record->{phase},'complete','completion retained outside target');
my ($id)=$intents[0] =~ m{/(batch-[^/]+)/intent.json};
is(index($id,'batch-_'),0,'resume fixture contains a generated underscore');
run($^X,"$RealBin/run-frozen-release.pl",'--root',$root,'--resume',$id);
open $f,'<',"$fixture/publications" or die $!;{local $/;is(<$f>,"alpha\nbeta\n",'complete resume never republishes');}close $f;
my $status=system($^X,"$RealBin/run-frozen-release.pl",'--root',$root,'--groups','gamma');
ok($status!=0,'new batch cannot silently absorb deferred uncommitted update');
# Durable Git objects include release commits; disposable worktree loss must not
# erase the only record of delivery.
is(output('git','--git-dir',"$root/.git/release-state/frozen/$id/repository.git",'show','HEAD:delivered'),"alpha\nbeta",'candidate commits remain in durable Git storage');
my $export="$fixture/export";make_path($export);
run('bash',"$RealBin/prepare-script-fixture.sh","$RealBin/../..",$export,'scripts/ci/run-frozen-release.pl');
ok(-f "$export/scripts/ci/validate-release-inputs.pl",'version admission exported');
my $refused=system($^X,"$RealBin/run-frozen-release.pl",'--root',$root,'--resume',$id,'--delivery','pr');
ok($refused!=0,'PR delivery cannot silently become direct delivery');
$record->{phase}='publishing'; $record->{index}=1;
write_file($intents[0],encode_json($record));
ok(system($^X,"$RealBin/run-frozen-release.pl",'--root',$root,'--resume',$id)!=0,
    'uncertain publication refuses automatic redispatch');
run($^X,"$RealBin/run-frozen-release.pl",'--root',$root,'--resume',$id,'--publication-result','published');
is(output('cat',"$fixture/publications"),"alpha\nbeta",'verified publication reconciliation does not upload again');

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
SHARED_TOOLING_ROOT := $(CURDIR)
RELEASE_FROZEN_GROUPS := alpha,beta
include make/release.mk
release-version:
	@sed -n 's/^version = "\(.*\)"/\1/p' $(RELEASE_GROUP)/Cargo.toml
release-verify:
	@! grep -q deferred Cargo.lock
	@if [ "$(RELEASE_GROUP)" = alpha ]; then printf '\n# deferred update\n' >> "$$DEVELOPMENT_ROOT/Cargo.lock"; fi
	@if [ "$(RELEASE_GROUP)" = beta ] && [ -f "$$FAIL_ONCE" ]; then rm "$$FAIL_ONCE"; exit 1; fi
release-prepare-version:
	@sed -i 's/0.1.0/0.1.1/g' $(RELEASE_GROUP)/Cargo.toml
	@sed -i '/^$(RELEASE_GROUP) = /s/0.1.0/0.1.1/' Cargo.toml
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
$ENV{FAIL_ONCE}="$fixture/fail-once"; write_file($ENV{FAIL_ONCE},'fail');
ok(system('make','--no-print-directory','-C',$real,'release-patch')!=0,'real second-group gate failure stops delivery');
is(output('git','--git-dir',"$fixture/real-remote.git",'tag','--list'),'alpha-v0.1.1','failed second group does not repeat or undo first delivery');
my @real_intents=glob("$real/.git/release-state/frozen/batch-*/intent.json");
my ($real_id)=$real_intents[0] =~ m{/(batch-[^/]+)/intent.json};
run($^X,"$RealBin/run-frozen-release.pl",'--root',$real,'--resume',$real_id);
is(output('git','--git-dir',"$fixture/real-remote.git",'tag','--list'),"alpha-v0.1.1\nbeta-v0.1.1",'real runner releases both groups through ordinary Make target');
like(output('git','-C',$real,'diff','--','Cargo.lock'),qr/deferred update/,'real runner preserves concurrent normal lock edit');
done_testing();
if (Test::More->builder->is_passing) {remove_tree($fixture)} else {warn "fixture retained: $fixture\n";}
