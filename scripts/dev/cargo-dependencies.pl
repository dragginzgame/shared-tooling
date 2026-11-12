#!/usr/bin/env perl
# Shared companions: scripts/ci/StableVersion.pm
use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin qw($RealBin);
use lib "$RealBin/../ci";
use StableVersion qw(stable version_cmp);
use JSON::PP;
use POSIX qw(strftime);
use Time::HiRes qw(time);

# Registry stable versions may carry build metadata; it has no precedence.
# Keep the stricter shared tool-pin grammar unchanged.
sub stable_core {
    my ($version) = @_;
    return unless defined $version;
    $version =~ s/\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*\z//;
    return stable($version) ? $version : undef;
}
sub release_cmp { version_cmp(stable_core($_[0]), stable_core($_[1])) }
sub colour {
    my ($code, $text, $stderr) = @_;
    my $terminal = $stderr ? -t STDERR : -t STDOUT;
    return $text if !$terminal || exists($ENV{NO_COLOR}) || ($ENV{TERM} // '') eq 'dumb';
    return "\e[${code}m$text\e[0m";
}

sub usage {
    return "Usage: cargo-dependencies.pl review|update [--consumer DIR] [--manifest RELATIVE/Cargo.toml] [--package NAME] [--precise VERSION] [--json] [--verbose]\n" .
        "Includes root and existing qualification workspaces; --manifest adds explicit workspaces.\n" .
        "Review uses locked offline metadata and online crates.io reads. Update changes locks, never requirements.\n" .
        "Exit 0: update succeeded or review current; 1: review found newer or yanked selections; 2: incomplete/invalid observation or update failure.\n";
}
sub read_file {
    open my $fh, '<', $_[0] or die "read $_[0]: $!\n";
    local $/; return <$fh>;
}
my ($evidence, $sequence, @updated);
$sequence = 0;
sub capture {
    my (@command) = @_;
    my $base = "$evidence/" . ++$sequence;
    open my $record, '>', "$base.command.json" or die $!;
    print {$record} encode_json({ cwd => getcwd(), command => \@command });
    close $record or die $!;
    my $pid = fork(); defined $pid or die "fork: $!\n";
    if (!$pid) {
        open STDOUT, '>', "$base.stdout" or die $!;
        open STDERR, '>', "$base.stderr" or die $!;
        exec { $command[0] } @command or die "exec $command[0]: $!\n";
    }
    waitpid($pid, 0) == $pid or die "wait: $!\n";
    my $status = $?;
    die "Command failed (@command), status $status; see $base.stderr\n" if $status;
    return read_file("$base.stdout");
}
my $status = eval {
    my $mode = shift @ARGV // '';
    if ($mode eq '--help' || $mode eq '-h') { print usage(); exit 0; }
    $mode =~ /\A(?:review|update)\z/ or die usage();
    my ($consumer, $package, $precise, $json, $verbose) = (getcwd(), undef, undef, 0, 0);
    my $started = time();
    my @extra;
    while (@ARGV) {
        my $arg = shift @ARGV;
        if ($arg eq '--json') { $json = 1; next; }
        if ($arg eq '--verbose') { $verbose = 1; next; }
        @ARGV or die usage();
        my $value = shift @ARGV;
        if ($arg eq '--consumer') { $consumer = $value; }
        elsif ($arg eq '--manifest') { push @extra, $value; }
        elsif ($arg eq '--package') { defined $package and die "select one package\n"; $package = $value; }
        elsif ($arg eq '--precise') { $precise = $value; }
        else { die usage(); }
    }
    !defined($package) || $package =~ /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/ or die "invalid package\n";
    !defined($precise) || ($mode eq 'update' && defined($package) && defined(stable_core($precise)))
        or die "--precise requires update, --package and a stable version\n";
    $consumer !~ /[\r\n]/ && -d $consumer or die "invalid consumer directory\n";
    $consumer = abs_path($consumer);
    $consumer !~ /[\r\n]/ or die "invalid resolved consumer directory\n";
    my @manifests = ('Cargo.toml');
    push @manifests, 'qualification/Cargo.toml' if -e "$consumer/qualification/Cargo.toml";
    push @manifests, @extra;
    my (%seen, @workspaces);
    for my $relative (@manifests) {
        $relative =~ m{\A(?:[a-zA-Z0-9_. -]+/)*Cargo\.toml\z} &&
            !grep { $_ eq '.' || $_ eq '..' } split m{/}, $relative
            or die "select a canonical repository-relative Cargo.toml: $relative\n";
        next if $seen{$relative}++;
        my $path = "$consumer/$relative";
        -f $path && !-l $path && abs_path($path) eq $path or die "missing or aliased manifest: $path\n";
        my $root = dirname($path);
        -f "$root/Cargo.lock" && !-l "$root/Cargo.lock" or die "missing regular lockfile: $root/Cargo.lock\n";
        push @workspaces, { manifest => $relative, root => $root };
    }
    make_path("$consumer/target");
    $evidence = tempdir('dependency-review.XXXXXX', DIR => "$consumer/target", CLEANUP => 0);
    # Every workspace is admitted before any update. Cargo, not this helper,
    # owns requirement matching, renamed dependencies and graph resolution.
    my $observe = sub {
        my ($ws) = @_;
        warn colour('36', "Inspecting $ws->{manifest}...", 1), "\n" unless $json;
        chdir $ws->{root} or die $!;
        my $data = decode_json(capture('cargo', 'metadata', '--locked', '--offline', '--all-features',
            '--format-version', '1', '--manifest-path', "$consumer/$ws->{manifest}"));
        ref($data) eq 'HASH' && ref($data->{packages}) eq 'ARRAY' &&
            ref($data->{workspace_members}) eq 'ARRAY' && ref($data->{resolve}{nodes}) eq 'ARRAY'
            or die "incomplete Cargo metadata: $ws->{manifest}\n";
        abs_path($data->{workspace_root}) eq $ws->{root}
            or die "manifest is not an independent workspace root: $ws->{manifest}\n";
        my %packages = map { $_->{id} => $_ } @{$data->{packages}};
        my %nodes = map { $_->{id} => $_ } @{$data->{resolve}{nodes}};
        my @rows;
        for my $id (@{$data->{workspace_members}}) {
            my $member = $packages{$id} or die "missing workspace member\n";
            my $node = $nodes{$id} or die "missing resolved member\n";
            for my $dep (@{$member->{dependencies}}) {
                next if defined($package) && $dep->{name} ne $package;
                my $alias = $dep->{rename} // $dep->{name}; $alias =~ tr/-/_/;
                my (%locked, %sources);
                for my $edge (@{$node->{deps}}) {
                    next unless $edge->{name} eq $alias;
                    my $selected = $packages{$edge->{pkg}} or die "missing resolved dependency\n";
                    $selected->{name} eq $dep->{name} or die "resolved dependency identity mismatch\n";
                    next unless grep {
                        ($_->{kind} // 'normal') eq ($dep->{kind} // 'normal') &&
                        ($_->{target} // '') eq ($dep->{target} // '')
                    } @{$edge->{dep_kinds}};
                    $locked{$selected->{version}} = 1;
                    $sources{$selected->{source} // 'path'} = 1;
                }
                push @rows, { workspace => $ws->{manifest}, member => $member->{name},
                    package => $dep->{name}, requirement => $dep->{req}, kind => $dep->{kind} // 'normal',
                    target => $dep->{target}, optional => $dep->{optional},
                    source => $dep->{source} // 'path', locked => [sort keys %locked],
                    resolved_sources => [sort keys %sources] };
            }
        }
        $ws->{rows} = \@rows;
    };
    # Resolve toolchains/config relative to the consumer, not the tooling checkout.
    chdir $consumer or die $!;
    $observe->($_) for @workspaces;
    !defined($package) || grep { @{$_->{rows}} } @workspaces or die "no direct dependency named $package\n";
    my @changed_locks;
    if ($mode eq 'update') {
        for my $ws (@workspaces) {
            next if defined($package) && !@{$ws->{rows}};
            chdir $ws->{root} or die $!;
            push @updated, $ws->{manifest}; # Includes the failing attempt: Cargo may have written.
            my @args = ('cargo', 'update', '-v', '--manifest-path', "$consumer/$ws->{manifest}");
            push @args, '--package', $package if defined $package;
            push @args, '--precise', $precise if defined $precise;
            my $before = read_file("$ws->{root}/Cargo.lock");
            warn colour('36', "Updating $ws->{manifest}...", 1), "\n" unless $json;
            capture(@args);
            if (read_file("$ws->{root}/Cargo.lock") ne $before) {
                push @changed_locks, $ws->{manifest} =~ s/Cargo\.toml\z/Cargo.lock/r;
            }
        }
        if (@changed_locks) { $observe->($_) for @workspaces; }
    }
    my %releases;
    my @rows = map { @{$_->{rows}} } @workspaces;
    if (grep { $_->{source} eq 'registry+https://github.com/rust-lang/crates.io-index' } @rows) {
        my $version = capture('curl', '--disable', '--version');
        $version =~ /^curl (\d+)\.(\d+)\./ && ($1 > 8 || ($1 == 8 && $2 >= 4))
            or die "bounded registry reads require curl >= 8.4\n";
    }
    # One bounded curl batch reuses connections instead of serial per-package processes.
    my %names = map { $_->{package} => 1 } grep {
        $_->{source} eq 'registry+https://github.com/rust-lang/crates.io-index'
    } @rows;
    my @requests = ('curl', '--disable', '--parallel', '--parallel-max', '6', '--fail-early');
    for my $name (sort keys %names) {
        $name =~ /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/ or die "invalid registry package\n";
        my $lower = lc $name;
        my $prefix = length($lower) == 1 ? '1' : length($lower) == 2 ? '2' :
            length($lower) == 3 ? '3/' . substr($lower, 0, 1) : substr($lower, 0, 2) . '/' . substr($lower, 2, 2);
        push @requests, '--next' if @requests > 7;
        push @requests, '--fail', '--silent', '--show-error', '--location',
            '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '10',
            '--max-time', '30', '--max-filesize', '16777216',
            '--output', "$evidence/registry-$name.ndjson", '--url', "https://index.crates.io/$prefix/$lower";
    }
    if (%names) {
        warn colour('36', 'Checking ' . scalar(keys %names) . ' unique registry packages (up to 6 concurrent requests)...', 1), "\n" unless $json;
        capture(@requests);
    }
    my $result = 0;
    for my $row (@rows) {
        my $name = $row->{package};
        if (grep { $_ ne $row->{source} } @{$row->{resolved_sources}}) {
            $row->{status} = 'source-override'; $result = 2; next;
        }
        if ($row->{source} ne 'registry+https://github.com/rust-lang/crates.io-index') {
            $row->{status} = $row->{source} eq 'path' ? 'local-path' : 'unsupported-source';
            $result = 2 if $row->{status} eq 'unsupported-source';
            next;
        }
        if (!exists $releases{$name}) {
            my $lower = lc $name;
            my $raw = read_file("$evidence/registry-$name.ndjson");
            my %versions;
            for my $line (split /\n/, $raw) {
                my $record = decode_json($line);
                ref($record) eq 'HASH' && lc($record->{name} // '') eq $lower &&
                    defined($record->{vers}) && JSON::PP::is_bool($record->{yanked}) or die "invalid registry record for $name\n";
                $versions{$record->{vers}} = $record->{yanked};
            }
            my @stable = sort { release_cmp($a, $b) || $a cmp $b } grep { defined(stable_core($_)) && !$versions{$_} } keys %versions;
            @stable or die "no stable non-yanked release for $name\n";
            $releases{$name} = { latest => $stable[-1], versions => \%versions };
        }
        my $release = $releases{$name};
        $row->{latest} = $release->{latest};
        $row->{status} = 'current';
        if (!@{$row->{locked}}) { $row->{status} = 'unresolved'; $result = 2; }
        for my $version (@{$row->{locked}}) {
            exists $release->{versions}{$version} or die "locked $name $version absent from registry\n";
            if ($release->{versions}{$version}) { $row->{status} = 'yanked'; }
            elsif ($row->{status} ne 'yanked' && (!defined(stable_core($version)) || release_cmp($version, $row->{latest}) != 0)) {
                $row->{status} = 'review';
            }
        }
        $result = 1 if !$result && $row->{status} ne 'current';
    }
    my %selections;
    for my $row (@rows) {
        next if $row->{source} eq 'path';
        $selections{$row->{package}}{$row->{workspace}}{$_} = 1 for @{$row->{locked}};
    }
    my @differences;
    for my $name (sort keys %selections) {
        my $workspaces = $selections{$name};
        my %sets = map { join(',', sort keys %$_) => 1 } values %$workspaces;
        next unless keys(%$workspaces) > 1 && keys(%sets) > 1;
        push @differences, { package => $name, workspaces => {
            map { $_ => [sort keys %{$workspaces->{$_}}] } sort keys %$workspaces } };
    }
    my $report = { mode => $mode, observed_at => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime),
        consumer => $consumer, manifests => [map { $_->{manifest} } @workspaces],
        rows => \@rows, differences => \@differences, update_attempts => \@updated,
        changed_lockfiles => \@changed_locks, evidence => $evidence, review_status => $result, elapsed_seconds => 0 + sprintf('%.2f', time() - $started) };
    if ($json) { print JSON::PP->new->canonical->pretty->encode($report); }
    else {
        my %summary;
        for my $row (@rows) {
            next if !$verbose && $row->{status} =~ /\A(?:current|local-path)\z/;
            my $key = join("\t", $row->{package}, join(',', @{$row->{locked}}) || '-', $row->{latest} // '-', $row->{status});
            $summary{$key}{$row->{workspace}} = 1;
        }
        for my $key (sort keys %summary) {
            my ($name, $locked, $latest, $state) = split /\t/, $key;
            my $tone = $state eq 'review' ? '33' : $state eq 'current' ? '32' : $state eq 'local-path' ? '2' : '31';
            print colour($tone, "$name  $locked -> $latest  $state"), ' [', join(', ', sort keys %{$summary{$key}}), "]\n";
        }
        for my $difference (@differences) {
            print "Different workspace selections: $difference->{package} ", join('; ', map {
                $_ . '=' . join(',', @{$difference->{workspaces}{$_}})
            } sort keys %{$difference->{workspaces}}), "\n";
        }
        if ($mode eq 'update') {
            print colour('32', @changed_locks ? 'Lockfiles changed: ' . join(', ', @changed_locks) : 'No lockfile changes.'), "\n";
        }
        print colour($result == 2 ? '31' : $result == 1 ? '33' : '32',
            $result == 2 ? 'Review incomplete.' : $result == 1 ? 'Newer/yanked selections remain; review constraints before migrating.' : 'No dependency updates need review.'), "\n";
        print scalar(@workspaces), " workspace(s), ", scalar(keys %names), " registry package(s), $report->{elapsed_seconds}s.\n";
        print 'Workspaces: ', join(', ', @{$report->{manifests}}), "\nEvidence: $evidence\n";
    }
    $mode eq 'update' && $result == 1 ? 0 : $result;
};
if ($@) {
    warn $@;
    warn 'Update attempts (locks may have changed; no rollback): ' . join(', ', @updated) . "\n" if @updated;
    warn "Evidence retained: $evidence\n" if defined $evidence;
    exit 2;
}
exit $status;
