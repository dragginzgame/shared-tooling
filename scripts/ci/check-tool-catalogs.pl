#!/usr/bin/env perl
# Shared companions: scripts/ci/tool-catalog-records.pl scripts/ci/verify-shared-tooling-snapshot.sh
use strict;
use warnings;
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);
use FindBin qw($RealBin);
use JSON::PP;

# Consumer-owned bindings/recorded CLI observations, not a shell/Make interpreter.
my ($consumer, $bindings, $json) = ('.', 'ci/tool-catalog-bindings.json', 0);
sub read_file {
    my ($path) = @_;
    open my $fh, '<', $path or die "cannot read $path: $!\n";
    local $/; my $bytes = <$fh> // '';
    close $fh or die "cannot close $path: $!\n";
    return $bytes;
}
sub scalar_text { defined($_[0]) && !ref($_[0]) && length($_[0]) && $_[0] !~ /[\0\r\n]/ }
sub local_path {
    my ($path) = @_;
    scalar_text($path) or die "missing path or CR/LF path\n";
    my $selected = $path =~ m{^/} ? $path : "$consumer/$path";
    my $physical = abs_path($selected);
    defined($physical) && $physical !~ /[\0\r\n]/ && -f $physical
        && index($physical, "$consumer/") == 0 or die "missing/outside/invalid consumer file: $path\n";
    return $physical;
}
sub fields {
    my ($value, @allowed) = @_;
    ref($value) eq 'HASH' or die "expected object\n";
    my %allowed = map { $_ => 1 } @allowed;
    !grep { !$allowed{$_} } keys %$value or die "unsupported field in binding\n";
}
my $exit = eval {
    while (@ARGV) {
        my $arg = shift @ARGV;
        if ($arg eq '--help') { print "usage: check-tool-catalogs.pl --consumer DIR --bindings FILE [--json]\n"; exit 0; }
        if ($arg eq '--json') { $json = 1; next; }
        @ARGV && ($arg eq '--consumer' || $arg eq '--bindings') or die "expected --consumer DIR --bindings FILE [--json]\n";
        if ($arg eq '--consumer') { $consumer = shift @ARGV; } else { $bindings = shift @ARGV; }
    }
    scalar_text($consumer) or die "invalid consumer directory\n";
    $consumer = abs_path($consumer) // die "missing consumer directory\n";
    $consumer !~ /[\0\r\n]/ && -d $consumer or die "invalid physical consumer directory\n";
    my $config = decode_json(read_file(local_path($bindings)));
    fields($config, qw(workflows));
    ref($config->{workflows}) eq 'ARRAY' && @{$config->{workflows}} or die "no workflows selected\n";
    my (@rows, %groups, $mismatch, $unresolved);
    for my $group (@{$config->{workflows}}) {
        fields($group, qw(name kind reference callers));
        scalar_text($group->{name}) && ($group->{kind} // '') =~ /\A(?:host|rust|ic)\z/
            && scalar_text($group->{reference}) && ref($group->{callers}) eq 'ARRAY' && @{$group->{callers}} >= 2
            or die "workflow requires name, kind, reference and at least two callers\n";
        my $identity = "$group->{name}\0$group->{kind}";
        !$groups{$identity}++ or die "duplicate workflow/kind\n";
        my (%roles, @selected);
        for my $caller (@{$group->{callers}}) {
            fields($caller, qw(role catalog source source_sha256 observation unresolved snapshot snapshot_root exception));
            scalar_text($caller->{role}) && !$roles{$caller->{role}}++ or die "missing/duplicate caller role\n";
            my $row = { workflow => $group->{name}, kind => $group->{kind}, role => $caller->{role} };
            my $ok = eval {
                die "$caller->{unresolved}\n" if exists $caller->{unresolved};
                my $selection = $caller;
                $row->{evidence} = 'declared binding (not runtime proof)';
                if (exists $caller->{observation}) {
                    !grep { exists $caller->{$_} } qw(catalog source source_sha256) or die "conflicting binding and observation\n";
                    $selection = decode_json(read_file(local_path($caller->{observation})));
                    fields($selection, qw(catalog source source_sha256));
                    $row->{evidence} = 'recorded CLI observation (not executed by checker)';
                }
                scalar_text($selection->{source_sha256}) && $selection->{source_sha256} =~ /\A[0-9a-f]{64}\z/
                    or die "missing source fingerprint\n";
                my $source = local_path($selection->{source});
                sha256_hex(read_file($source)) eq $selection->{source_sha256} or die "stale caller source fingerprint\n";
                my $catalog = local_path($selection->{catalog});
                $row->{catalog} = $selection->{catalog};
                $row->{source} = $selection->{source};
                if (exists $caller->{exception}) {
                    scalar_text($caller->{exception}) && !exists($caller->{snapshot}) && !exists($caller->{snapshot_root})
                        or die "conflicting/empty catalog ownership\n";
                    $row->{owner} = "exception: $caller->{exception}";
                } else {
                    my $manifest_path = local_path($caller->{snapshot});
                    scalar_text($caller->{snapshot_root}) or die "missing snapshot consumer root\n";
                    my $base = $caller->{snapshot_root} eq '.' ? $consumer : abs_path("$consumer/$caller->{snapshot_root}");
                    defined($base) && $base !~ /[\0\r\n]/ && ($base eq $consumer || index($base, "$consumer/") == 0)
                        or die "invalid snapshot root\n";
                    # Read with our reviewed grammar owner, never consumer code.
                    open my $reader, '-|', 'bash', "$RealBin/verify-shared-tooling-snapshot.sh", '--read-manifest', $manifest_path
                        or die "cannot start snapshot reader: $!\n";
                    my $manifest = do { local $/; <$reader> // '' };
                    close $reader or die "invalid owning snapshot manifest\n";
                    my ($revision, @matched);
                    for my $line (split /\n/, $manifest) {
                        my ($record, @values) = split /\t/, $line, -1;
                        if ($record eq 'revision') { $revision = $values[0]; }
                        next unless $record eq 'file';
                        my ($digest, undef, $path) = @values;
                        my $resolved = abs_path("$base/$path");
                        push @matched, $digest if defined($resolved) && $resolved eq $catalog;
                    }
                    @matched == 1 && $matched[0] eq sha256_hex(read_file($catalog)) or die "catalog missing or changed in owning snapshot\n";
                    $row->{owner} = "snapshot $caller->{snapshot} at $revision";
                }
                open my $parser, '-|', $^X, "$RealBin/tool-catalog-records.pl", $group->{kind}, $catalog
                    or die "cannot start catalog parser: $!\n";
                my %records;
                while (my $line = <$parser>) {
                    chomp $line;
                    my ($tool, $version, $host, $digest) = split /\t/, $line, -1;
                    defined($digest) or die "invalid catalog projection\n";
                    $records{"$tool/$host"} = "$version/$digest";
                }
                close $parser or die "catalog records unavailable\n";
                keys %records or die "empty catalog projection\n";
                $row->{records} = \%records;
                $row->{status} = 'AGREES';
                1;
            };
            if (!$ok) { $row->{status} = 'UNRESOLVED'; $row->{reason} = $@; chomp $row->{reason}; $unresolved = 1; }
            push @selected, $row;
        }
        my ($reference) = grep { $_->{role} eq $group->{reference} } @selected;
        defined($reference) or die "reference role missing\n";
        for my $row (@selected) {
            next if $row->{status} eq 'UNRESOLVED';
            if ($reference->{status} eq 'UNRESOLVED') {
                $row->{status} = 'UNRESOLVED'; $row->{reason} = 'reference selection unresolved'; $unresolved = 1; next;
            }
            my %keys = map { $_ => 1 } (keys %{$reference->{records}}, keys %{$row->{records}});
            my @differences;
            for my $key (sort keys %keys) {
                my $expected = $reference->{records}{$key} // '(missing)';
                my $actual = $row->{records}{$key} // '(missing)';
                push @differences, { tool_host => $key, reference => $expected, selected => $actual } if $actual ne $expected;
            }
            if (@differences) { $row->{status} = 'DIFFERS'; $row->{differences} = \@differences; $mismatch = 1; }
        }
        delete $_->{records} for @selected;
        push @rows, @selected;
    }
    my $result = { scope => 'Selected caller bindings only; no automatic caller discovery or runtime execution', callers => \@rows };
    if ($json) { print JSON::PP->new->canonical->pretty->encode($result); }
    else {
        print "$result->{scope}\n";
        for my $row (@rows) {
            print join(' | ', map { $row->{$_} // '-' } qw(status workflow kind role catalog owner evidence)), "\n";
            print "  $row->{reason}\n" if $row->{reason};
            for my $diff (@{$row->{differences} // []}) { print "  $diff->{tool_host}: $diff->{selected}; reference $diff->{reference}\n"; }
        }
    }
    $unresolved ? 2 : $mismatch ? 1 : 0;
};
if ($@) { print STDERR "catalog selection unresolved: $@"; exit 2; }
exit $exit;
