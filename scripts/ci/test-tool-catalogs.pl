#!/usr/bin/env perl
# Shared companions: scripts/ci/check-tool-catalogs.pl ci/ic-tools.tsv ci/tool-versions.env
use strict;
use warnings;
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use FindBin qw($RealBin);
use JSON::PP;
use Test::More;
use POSIX qw(WIFEXITED WEXITSTATUS);
my $root = abs_path("$RealBin/../..");
my $fixture = abs_path(tempdir('tool-catalogs.XXXXXX', TMPDIR => 1, CLEANUP => 0));
my $complete;
END {
    if ($complete && $? == 0) {
        chdir $root or die "cannot leave fixture before cleanup: $!\n";
        remove_tree($fixture);
        die "Catalog cleanup incomplete: $fixture\n" if -e $fixture;
    } else { warn "Catalog fixtures retained: $fixture\n"; }
}
sub read_file { open my $f, '<', $_[0] or die $!; local $/; return <$f>; }
sub write_file { open my $f, '>', "$fixture/$_[0]" or die $!; print {$f} $_[1]; close $f or die $!; }
make_path("$fixture/ci", "$fixture/vendor/ci");
chdir $fixture or die $!;
my $ic = read_file("$root/ci/ic-tools.tsv");
my $qualified = $ic; $qualified =~ s/wasm-opt\t[0-9]+\t/wasm-opt\t132\t/g;
write_file('ci/default.tsv', $ic);
write_file('ci/qualified.tsv', $qualified);
write_file('ci/host.env', read_file("$root/ci/tool-versions.env"));
sub run_records {
    my (@arguments) = @_;
    open my $output, '-|', $^X, "$root/scripts/ci/tool-catalog-records.pl", @arguments or die $!;
    my $bytes = do { local $/; <$output> // '' }; close $output;
    my $status = $?;
    WIFEXITED($status) or die "catalog parser did not exit normally\n";
    return (WEXITSTATUS($status), $bytes);
}
my ($record_status, $record_bytes) = run_records('rust', 'ci/host.env', 'CARGO_SORT');
is($record_status, 0, 'select one admitted Rust pin');
like($record_bytes, qr/\ACARGO_SORT\t[0-9.]+\tall\t-\n\z/, 'selection retains the typed record');
for my $version ('0.0.0', '18446744073709551616.2.3') {
    my $catalog = read_file("$fixture/ci/host.env");
    $catalog =~ s/(SHARED_TOOLING_CARGO_SORT_VERSION=)[^\n]+/$1$version/;
    write_file('ci/versions.env', $catalog);
    ($record_status, $record_bytes) = run_records('rust', 'ci/versions.env', 'CARGO_SORT');
    is($record_status, 0, 'catalog stable versions retain grammar-only admission without release bounds');
    like($record_bytes, qr/\ACARGO_SORT\t\Q$version\E\t/, 'catalog version bytes are preserved');
}
for my $version ('01.2.3', '1.02.3', '1.2.03', '1.2', '1.2.3-rc.1', '1.2.3+build') {
    my $catalog = read_file("$fixture/ci/host.env");
    $catalog =~ s/(SHARED_TOOLING_CARGO_SORT_VERSION=)[^\n]+/$1$version/;
    write_file('ci/versions.env', $catalog);
    ($record_status, $record_bytes) = run_records('rust', 'ci/versions.env');
    isnt($record_status, 0, 'catalog refuses a noncanonical stable version');
    is($record_bytes, '', 'invalid stable version publishes no partial catalog');
}
($record_status, $record_bytes) = run_records('host', 'ci/host.env', 'JQ');
is($record_status, 0, 'select host tool across its qualified hosts');
is(scalar(split /\n/, $record_bytes), 4, 'host selection preserves all four host identities');
($record_status, $record_bytes) = run_records('ic', 'ci/default.tsv', 'quill');
is($record_status, 0, 'select IC tool through the canonical pin parser');
like($record_bytes, qr/\Aquill\t/, 'IC selection retains canonical lowercase tool identity');
open my $matrix, '-|', 'awk', '-f', "$root/scripts/ci/ic-tool-pins.awk", 'ci/default.tsv' or die $!;
my @matrix_records = <$matrix>;
close $matrix or die "IC matrix admission failed\n";
is(join('', sort @matrix_records),
    join('', sort map { "$_\n" } grep { length && !/^#/ } split /\n/, $ic),
    'direct IC admission emits the complete unchanged matrix');
my ($last_record) = $ic =~ /([^\n]+)\n?\z/;
for my $invalid_ic ($ic . "$last_record\n", $ic =~ s/\Q$last_record\E\n?\z//r,
    $ic =~ s/\Q$last_record\E\n?\z/invalid\n/r) {
    write_file('ci/invalid-selection.tsv', $invalid_ic);
    ($record_status, $record_bytes) = run_records('ic', 'ci/invalid-selection.tsv', 'quill');
    isnt($record_status, 0, 'IC selection cannot hide incomplete or corrupt matrix records');
    is($record_bytes, '', 'failed IC matrix admission publishes no partial selection');
}
($record_status, $record_bytes) = run_records('ci', 'ci/host.env');
is($record_status, 0, 'admit the common CI pins');
is(scalar(split /\n/, $record_bytes), 3, 'one record per reviewed CI tool');
my ($optional_status, $optional_bytes) = run_records('ci', 'ci/host.env', 'SCCACHE');
is($optional_status, 0, 'optional sccache has a canonical selection');
like($optional_bytes, qr/^SCCACHE\t0\.19\.0\tLINUX_AMD64\t[0-9a-f]{64}\n$/, 'optional compiler cache uses its reviewed asset identity');
like($record_bytes, qr/^SHELLCHECK\t[^\t]+\tLINUX_AMD64\t[0-9a-f]{64}$/m, 'asset-specific checksum keys project one host identity');
($record_status, $record_bytes) = run_records('rust', 'ci/host.env', 'UNKNOWN');
isnt($record_status, 0, 'missing selected tool refuses');
is($record_bytes, '', 'missing selection publishes no records');
my $invalid_ci = read_file("$fixture/ci/host.env");
$invalid_ci =~ s/(SHARED_TOOLING_GITLEAKS_SHA256_LINUX_X64=)[^\n]+/${1}invalid/;
write_file('ci/invalid-ci.env', $invalid_ci);
($record_status, $record_bytes) = run_records('ci', 'ci/invalid-ci.env', 'ACTIONLINT');
isnt($record_status, 0, 'selection cannot hide invalid records in its catalog group');
is($record_bytes, '', 'incomplete admission publishes no partial records');
write_file('caller.sh', "# reviewed consumer adapter\n");
sub binding_entry {
    my ($role, $catalog) = @_;
    return { role => $role, catalog => $catalog, source => 'caller.sh', source_sha256 => sha256_hex(read_file("$fixture/caller.sh")), exception => 'consumer-qualified pins' };
}
my $config = { workflows => [{ name => 'release', kind => 'ic', reference => 'setup', callers => [binding_entry('setup', 'ci/qualified.tsv'), binding_entry('collector', 'ci/qualified.tsv'), binding_entry('verifier', 'ci/qualified.tsv')] }] };
sub run_check {
    my ($checker) = @_;
    $checker //= "$root/scripts/ci/check-tool-catalogs.pl";
    write_file('bindings.json', encode_json($config));
    open my $output, '-|', $^X, $checker, '--consumer', $fixture, '--bindings', 'bindings.json', '--json' or die $!;
    my $bytes = do { local $/; <$output> }; close $output;
    my $status = $?;
    unless (WIFEXITED($status)) {
        print STDERR $bytes // '';
        die "catalog checker did not exit normally (wait status $status)\n";
    }
    return (WEXITSTATUS($status), length($bytes) ? decode_json($bytes) : {});
}
my ($status, $result) = run_check();
is($status, 0, 'all IC callers use qualified 132; unused 133 coexists');
like($result->{callers}[0]{evidence}, qr/not runtime proof/, 'declarations do not claim runtime proof');
$config->{workflows}[0]{callers}[2]{catalog} = 'ci/default.tsv';
($status, $result) = run_check();
is($status, 1, 'stale verifier catalog differs');
is($result->{callers}[2]{role}, 'verifier', 'identifies stale role');
is($result->{callers}[2]{status}, 'DIFFERS', 'identifies differing selection');
is(scalar @{$result->{callers}[2]{differences}}, 3, 'all affected host records reported');
my $changed = $qualified;
$changed =~ s/^(wasm-opt\t132\tdarwin-arm64\t)[0-9a-f]{64}$/${1} . ('0' x 64)/me;
write_file('ci/digest.tsv', $changed);
$config->{workflows}[0]{callers}[2]{catalog} = 'ci/digest.tsv';
($status, $result) = run_check();
is($status, 1, 'same version different digest rejected');
is(scalar @{$result->{callers}[2]{differences}}, 1, 'single-host difference retained');
write_file('ci/reordered.tsv', "# comment\n" . join("\n", reverse grep { !/^#/ } split /\n/, $qualified) . "\n");
$config->{workflows}[0]{callers}[2]{catalog} = 'ci/reordered.tsv';
is((run_check())[0], 0, 'different path/order/comments preserve semantic agreement');
# A consumer CLI emits its actual selected path and a fingerprint of its source.
# The checker reads its captured output; it never dispatches this consumer code.
write_file('selector.pl', <<'SELECTOR');
use strict; use warnings; use Digest::SHA qw(sha256_hex); use JSON::PP;
open my $self, '<', $0 or die $!; local $/; my $bytes=<$self>;
print encode_json({catalog=>'ci/default.tsv', source=>'selector.pl', source_sha256=>sha256_hex($bytes)});
SELECTOR
open my $cli, '-|', $^X, "$fixture/selector.pl" or die $!;
my $observed = do { local $/; <$cli> }; close $cli or die 'consumer selection failed';
write_file('observation.json', $observed);
$config->{workflows}[0]{callers}[2] = { role => 'verifier', observation => 'observation.json', exception => 'consumer-qualified pins' };
($status, $result) = run_check();
is($status, 1, 'actual consumer selector CLI exposes stale verifier selection');
like($result->{callers}[2]{evidence}, qr/recorded CLI/, 'recorded observation labelled independently');
write_file('selector.pl', read_file("$fixture/selector.pl") . "# changed caller\n");
is((run_check())[0], 2, 'stale source-bound observation unresolved');
$config->{workflows}[0]{callers}[2] = {role => 'verifier', unresolved => 'computed selector needs consumer binding'};
is((run_check())[0], 2, 'unsupported selection never passes');
$config->{workflows}[0]{callers}[1]{catalog} = 'ci/default.tsv';
($status, $result) = run_check();
is($status, 2, 'unknown caller keeps overall result unresolved');
is($result->{callers}[1]{status}, 'DIFFERS', 'known mismatch still reported beside unresolved caller');
$config->{workflows}[0]{callers}[1]{catalog} = 'ci/qualified.tsv';
$config->{workflows}[0]{callers}[2] = binding_entry('verifier', 'ci/missing.tsv');
is((run_check())[0], 2, 'missing catalog unresolved');
$config->{workflows}[0]{callers}[2] = binding_entry('verifier', 'ci/qualified.tsv');
$config->{workflows}[0]{callers}[2]{observation} = 'observation.json';
is((run_check())[0], 2, 'conflicting binding and observation unresolved');
$config->{workflows}[0]{callers}[2] = binding_entry('verifier', '../outside.tsv');
is((run_check())[0], 2, 'outside catalog unresolved');
write_file('ci/invalid.tsv', $qualified . "unknown\t1.2.3\tlinux-x86_64\t" . ('0' x 64) . "\n");
$config->{workflows}[0]{callers}[2] = binding_entry('verifier', 'ci/invalid.tsv');
is((run_check())[0], 2, 'canonical IC parser rejects invalid records');
$config->{workflows}[0]{callers}[2] = binding_entry('verifier', 'ci/qualified.tsv');
# Root and nested ownership are independent of the path of the binding file.
for my $prefix ('', 'vendor/') {
    write_file("${prefix}ci/owned.tsv", $qualified);
    my $manifest = "format\t1\nsource\thttps://github.com/dragginzgame/shared-tooling\nrevision\t" . ('1' x 40) . "\nfile\t" . sha256_hex($qualified) . "\t-\tci/owned.tsv\n";
    write_file("${prefix}.shared-tooling.snapshot", $manifest);
    my $entry = binding_entry('verifier', "${prefix}ci/owned.tsv");
    delete $entry->{exception};
    $entry->{snapshot} = "${prefix}.shared-tooling.snapshot";
    $entry->{snapshot_root} = $prefix ? 'vendor' : '.';
    $config->{workflows}[0]{callers}[2] = $entry;
    is((run_check())[0], 0, "selected catalog owned by ${prefix}snapshot");
    for my $invalid (
        $manifest . "unknown\tignored\n",
        $manifest . "format\t1\n",
        $manifest =~ s/^source[^\n]*\n//mr,
        $manifest =~ s/^file\t([^\n]*)$/file\t$1\textra/mr,
        $manifest =~ s/ci\/owned.tsv/ci\/..\/ci\/owned.tsv/r,
        $manifest . "file\t" . sha256_hex($qualified) . "\t-\tci/owned.tsv\n",
        $manifest . "\0",
    ) {
        write_file("${prefix}.shared-tooling.snapshot", $invalid);
        ($status, $result) = run_check();
        is($status, 2, 'malformed owning manifest is unresolved');
        like($result->{callers}[2]{reason}, qr/invalid owning snapshot manifest/, 'canonical reader failure reaches caller evidence');
    }
    # Syntax admission must not turn this selected-catalog check into whole-
    # snapshot verification: unrelated payloads can be absent here.
    write_file("${prefix}.shared-tooling.snapshot", $manifest . "file\t" . ('0' x 64) . "\t-\tunselected.txt\n");
    is((run_check())[0], 0, 'unselected payload integrity remains a separate check');
    make_path("$fixture/reader-failure/scripts/ci");
    for my $script (qw(check-tool-catalogs.pl tool-catalog-records.pl ic-tool-pins.awk StableVersion.pm)) {
        copy("$root/scripts/ci/$script", "$fixture/reader-failure/scripts/ci/$script") or die $!;
    }
    write_file('reader-failure/scripts/ci/verify-shared-tooling-snapshot.sh', "#!/usr/bin/env bash\ncat <<'RECORDS'\n${manifest}RECORDS\nexit 91\n");
    is((run_check("$fixture/reader-failure/scripts/ci/check-tool-catalogs.pl"))[0], 2,
        'failed reader cannot admit even complete valid output');
    write_file("${prefix}.shared-tooling.snapshot", $manifest);
    write_file("${prefix}ci/owned.tsv", $changed);
    is((run_check())[0], 2, 'snapshot catalog mutation unresolved');
}
# A host exception is not inherited by the Rust selection.
my $host = read_file("$fixture/ci/host.env");
$host =~ s/SHARED_TOOLING_JQ_VERSION=[^\n]+/SHARED_TOOLING_JQ_VERSION=9.9.9/;
write_file('ci/host-exception.env', $host);
$config->{workflows} = [map { {name => 'release', kind => $_, reference => 'setup', callers => [binding_entry('setup','ci/host.env'), binding_entry('verifier','ci/host-exception.env')]} } qw(host rust)];
($status, $result) = run_check();
is($status, 1, 'host exception difference detected');
is($result->{callers}[1]{status}, 'DIFFERS', 'host group differs');
is($result->{callers}[3]{status}, 'AGREES', 'same catalogs agree for independent Rust selection');
write_file('ci/host-exception.env', $host . "touch SHOULD_NOT_EXIST\n");
is((run_check())[0], 2, 'executable catalog unresolved, not sourced');
ok(!-e "$fixture/SHOULD_NOT_EXIST", 'inspection executed no catalog commands');
$config->{workflows}[0]{callers}[1]{role} = 'setup';
is((run_check())[0], 2, 'duplicate role refused');
done_testing();
$complete = Test::More->builder->is_passing;
