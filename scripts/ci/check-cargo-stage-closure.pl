#!/usr/bin/env perl
# Shared companions: docs/release-validation-reuse.md
use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use JSON::PP;
@ARGV==3 or die "usage: check-cargo-stage-closure.pl ACTUAL CANDIDATE PRIMARY\n";
my ($actual,$candidate,$primary)=@ARGV;
$primary =~ /\A[A-Za-z0-9][A-Za-z0-9_-]*\z/ or die "invalid primary\n";
my $json=JSON::PP->new->canonical->utf8;
sub graph {
    my ($root)=@_; $root=abs_path($root)//die "missing closure root\n";
    my $original=getcwd(); chdir $root or die $!;
    open my $in,'-|','cargo','metadata','--offline','--locked','--all-features','--format-version','1' or die $!;
    local $/; my $raw=<$in>; close $in or die "closure metadata failed\n";
    chdir $original or die $!;
    # Physical roots differ; Cargo package/feature/dependency identities may not.
    $raw =~ s/\Q$root\E/<source>/g;
    my $meta=$json->decode($raw);
    my %packages=map {$_->{id}=>$_} @{$meta->{packages}};
    my %nodes=map {$_->{id}=>$_} @{$meta->{resolve}{nodes}};
    my @roots=grep {$_->{name} eq $primary && !defined($_->{source})} values %packages;
    @roots==1 or die "ambiguous publication primary\n";
    my (@closure,%seen); my @queue=($roots[0]{id});
    while (@queue) {
        my $id=shift @queue; next if $seen{$id}++;
        my $node=$nodes{$id}//die "missing resolved closure node\n";
        push @closure,{package=>$packages{$id}//die("missing closure package\n"),node=>$node};
        push @queue,@{$node->{dependencies}};
    }
    return [sort {$a->{package}{id} cmp $b->{package}{id}} @closure];
}
$json->encode(graph($actual)) eq $json->encode(graph($candidate))
    or die "actual publication closure differs from qualified final candidate\n";
print "Publication package, target, feature and dependency closure matches final candidate: $primary\n";
