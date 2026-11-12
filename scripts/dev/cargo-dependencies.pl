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

sub usage {
    return "Usage: cargo-dependencies.pl review|update [--consumer DIR] [--manifest RELATIVE/Cargo.toml] [--package NAME] [--precise VERSION] [--json]\n" .
        "Includes root and existing qualification workspaces; --manifest adds explicit workspaces.\n" .
        "Review uses locked offline metadata and online crates.io reads. Update changes locks, never requirements.\n" .
        "Exit 0: reviewed/current; 1: newer or yanked selections; 2: incomplete/invalid observation or update failure.\n";
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
    my ($consumer, $package, $precise, $json) = (getcwd(), undef, undef, 0);
    my @extra;
    while (@ARGV) {
        my $arg = shift @ARGV;
        if ($arg eq '--json') { $json = 1; next; }
        @ARGV or die usage();
        my $value = shift @ARGV;
        if ($arg eq '--consumer') { $consumer = $value; }
        elsif ($arg eq '--manifest') { push @extra, $value; }
        elsif ($arg eq '--package') { defined $package and die "select one package\n"; $package = $value; }
        elsif ($arg eq '--precise') { $precise = $value; }
        else { die usage(); }
    }
    !defined($package) || $package =~ /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/ or die "invalid package\n";
    !defined($precise) || ($mode eq 'update' && defined($package) && stable($precise))
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
    if ($mode eq 'update') {
        for my $ws (@workspaces) {
            next if defined($package) && !@{$ws->{rows}};
            chdir $ws->{root} or die $!;
            push @updated, $ws->{manifest}; # Includes the failing attempt: Cargo may have written.
            my @args = ('cargo', 'update', '-v', '--manifest-path', "$consumer/$ws->{manifest}");
            push @args, '--package', $package if defined $package;
            push @args, '--precise', $precise if defined $precise;
            capture(@args);
        }
        $observe->($_) for @workspaces;
    }
    my %releases;
    my @rows = map { @{$_->{rows}} } @workspaces;
    if (grep { $_->{source} eq 'registry+https://github.com/rust-lang/crates.io-index' } @rows) {
        my $version = capture('curl', '--disable', '--version');
        $version =~ /^curl (\d+)\.(\d+)\./ && ($1 > 8 || ($1 == 8 && $2 >= 4))
            or die "bounded registry reads require curl >= 8.4\n";
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
            $name =~ /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/ or die "invalid registry package\n";
            my $lower = lc $name;
            my $prefix = length($lower) == 1 ? '1' : length($lower) == 2 ? '2' :
                length($lower) == 3 ? '3/' . substr($lower, 0, 1) : substr($lower, 0, 2) . '/' . substr($lower, 2, 2);
            my $raw = capture('curl', '--disable', '--fail', '--silent', '--show-error', '--location',
                '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '10',
                '--max-time', '30', '--max-filesize', '16777216', "https://index.crates.io/$prefix/$lower");
            my %versions;
            for my $line (split /\n/, $raw) {
                my $record = decode_json($line);
                ref($record) eq 'HASH' && lc($record->{name} // '') eq $lower &&
                    defined($record->{vers}) && JSON::PP::is_bool($record->{yanked}) or die "invalid registry record for $name\n";
                $versions{$record->{vers}} = $record->{yanked};
            }
            my @stable = sort { version_cmp($a, $b) } grep { stable($_) && !$versions{$_} } keys %versions;
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
            elsif ($row->{status} ne 'yanked' && (!stable($version) || version_cmp($version, $row->{latest}) != 0)) {
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
        rows => \@rows, differences => \@differences, update_attempts => \@updated, evidence => $evidence };
    if ($json) { print JSON::PP->new->canonical->pretty->encode($report); }
    else {
        print "$_->{workspace} / $_->{member}: $_->{package} $_->{requirement} [$_->{kind}]\n",
            '  locked=', join(',', @{$_->{locked}}) || '-', ' latest=', $_->{latest} // '-', " $_->{status}\n" for @rows;
        print "Different workspace selections: $_->{package}\n" for @differences;
        print 'Workspaces: ', join(', ', @{$report->{manifests}}), "\nEvidence: $evidence\n";
    }
    $result;
};
if ($@) {
    warn $@;
    warn 'Update attempts (locks may have changed; no rollback): ' . join(', ', @updated) . "\n" if @updated;
    warn "Evidence retained: $evidence\n" if defined $evidence;
    exit 2;
}
exit $status;
