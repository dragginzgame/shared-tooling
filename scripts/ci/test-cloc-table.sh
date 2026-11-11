#!/usr/bin/env bash
# Shared companions: scripts/dev/cloc-classify.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
mkdir -p "$root/target/tmp"
fixture="$(fixture_create "$root/target/tmp/cloc-table.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "LOC table fixture retained"' EXIT
perl -MJSON::PP -e '
    my $counts={library_app=>1234567,tests=>7714,examples=>865,benchmarks=>0,build_tooling=>248,unclassified=>0,total=>1243394};
    print encode_json({workspaces=>[
        {name=>"icydb",report=>{totals=>$counts,crates=>[
            {crate=>"qualification/icydb-testing-audit-default-empty-fixtures",counts=>$counts},
            {crate=>"qualification/icydb-testing-audit-ten-simple-fixtures",counts=>$counts}]}},
        {name=>"unavailable",status=>"n/a"}],totals=>$counts});
' > "$fixture/report.json"
renderer="$root/scripts/dev/cloc-classify.pl"
perl "$renderer" --table "$fixture/report.json" -d 0 > "$fixture/default"
perl "$renderer" --table "$fixture/report.json" --columns 80 -d 0 > "$fixture/narrow"
perl "$renderer" --table "$fixture/report.json" -d 0 --wide > "$fixture/wide"
perl -CSD -e '
    my ($base)=@ARGV;
    my %rows;
    for my $mode (qw(default narrow wide)) {
        open my $f,"<:encoding(UTF-8)","$base/$mode" or die $!;
        my @lines=<$f>; chomp @lines;
        my ($column)=($lines[0] =~ /^(.*?)app\/lib/);
        my $width=length($column)-5;
        die "default cap" if $mode eq "default" && $width != 44;
        die "narrow cap" if $mode eq "narrow" && grep {length($_)>80} @lines;
        die "wide names lost" if $mode eq "wide" && !grep {/qualification\/icydb-testing-audit-default-empty-fixtures/} @lines;
        die "suffix lost" if $mode ne "wide" && !grep {/\x{2026}.*fixtures/} @lines;
        my @data=grep {!/^[- ]+$/ && !/^workspace\/crate/} @lines;
        $rows{$mode}=[map {substr($_,$width)} @data];
        die "numeric alignment" if grep {substr($_,$width) !~ /^ +(?:[0-9]+|n\/a)/} @data;
    }
    die "counts changed" unless join("\n",@{$rows{default}}) eq join("\n",@{$rows{narrow}})
        && join("\n",@{$rows{default}}) eq join("\n",@{$rows{wide}});
' "$fixture"
fixture_complete=true
echo 'LOC table: bounded names, retained suffixes, full-width escape and unchanged aligned counts passed'
