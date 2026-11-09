#!/usr/bin/env perl
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempfile);
use FindBin;
use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json);

# Central fleet report, not a consumer export or a build/deployment gate.
my $root = abs_path("$FindBin::Bin/../..");
my ($parent, $catalog_file, $output_root, $write, $check, $help);
GetOptions('parent=s' => \$parent, 'catalog=s' => \$catalog_file,
    'output-root=s' => \$output_root, 'write' => \$write, 'check' => \$check,
    'help' => \$help) or die "Use --help for usage\n";
if ($help) {
    print "Usage: perl scripts/dev/stack-graph.pl (--write | --check) [--parent DIR]\n",
        "Read catalogued sibling manifests offline, then update or check the README\n",
        "overview and docs/stack.md evidence. No builds, downloads or sibling edits.\n",
        "Advanced: --catalog FILE --output-root DIR (defaults to this checkout).\n";
    exit 0;
}
die "Select exactly one of --write or --check; use --help\n"
    if @ARGV || (!!$write == !!$check);
$parent //= "$root/..";
$parent = abs_path($parent) // die "Cannot find sibling parent\n";
$output_root //= $root;
$catalog_file //= "$root/docs/stack-catalog.json";

sub read_file {
    my ($file) = @_;
    open my $fh, '<', $file or die "Cannot read $file: $!\n";
    local $/;
    return <$fh>;
}
sub under {
    my ($path, $prefix) = @_;
    return $path eq $prefix || index($path, "$prefix/") == 0;
}
my %repos;
sub source_link {
    my ($repo, $path) = @_;
    # Escape bytes that can change Markdown or URL structure, retaining slashes.
    $path =~ s/([^A-Za-z0-9_.~\/-])/sprintf('%%%02X', ord($1))/ge;
    return "https://github.com/dragginzgame/$repo/blob/$repos{$repo}/$path";
}
sub node_id {
    my $id = shift;
    $id =~ s/([^A-Za-z0-9])/sprintf('_%02x', ord($1))/ge;
    return "p_$id";
}
sub text_cell {
    my $text = shift // '';
    $text =~ s/&/&amp;/g;
    $text =~ s/([<>|`\r\n])/sprintf('&#%d;', ord($1))/ge;
    return $text;
}

my $catalog = decode_json(read_file($catalog_file));
die "Catalog needs nonempty roots and repositories\n"
    unless ref($catalog) eq 'HASH' && ref($catalog->{roots}) eq 'ARRAY' && @{$catalog->{roots}}
        && ref($catalog->{repositories}) eq 'ARRAY' && @{$catalog->{repositories}};
my (%workspaces, %owner, %nodes, %selected, @packages, @npm, %edges, %inventory, %groups);
for my $repo (@{$catalog->{repositories}}) {
    my $name = $repo->{name};
    die "Invalid or duplicate repository name\n"
        unless defined($name) && $name =~ /^[a-z][a-z0-9-]*$/ && !exists($repos{$name});
    $repos{$name} = $repo->{branch} // 'main';
    die "Invalid source-link branch for $name\n" unless $repos{$name} =~ /^[a-zA-Z0-9_.-]+$/;
    die "Catalog needs package paths for $name\n" unless ref($repo->{paths}) eq 'ARRAY' && @{$repo->{paths}};
    for my $path (@{$repo->{paths}}, @{$repo->{exclude} // []}, @{$repo->{native} // []}, @{$repo->{npm} // []}) {
        die "Invalid catalog path for $name\n"
            unless $path =~ m{^[a-zA-Z0-9_-]+(?:/[a-zA-Z0-9_.-]+)*$}
                && $path !~ m{(?:^|/)\.\.(?:/|$)};
    }
    die "Missing checkout: $name\n" unless -f "$parent/$name/Cargo.toml";
    die "Symlink checkout is not supported: $name\n" if -l "$parent/$name";
    $workspaces{$name} = abs_path("$parent/$name") // die "Missing checkout: $name\n";
}
die "Unknown diagram root\n" for grep { !$repos{$_} } @{$catalog->{roots}};
for my $repo (@{$catalog->{repositories}}) {
    my $name = $repo->{name};
    my $workspace = $workspaces{$name};
    print STDERR "stack graph: $name\n";
    # Keep the caller's prepared Cargo/toolchain and configuration. --no-deps
    # reads declarations, not a resolved feature or version graph.
    open my $cargo, '-|', 'cargo', 'metadata', '--manifest-path', "$workspace/Cargo.toml",
        '--format-version', '1', '--no-deps', '--offline', '--locked'
        or die "Cannot start Cargo: $!\n";
    my $json = do { local $/; <$cargo> };
    close $cargo or die "Cargo metadata failed for $name (status $?)\n";
    my $metadata = decode_json($json);
    die "Unexpected workspace root for $name\n" unless $metadata->{workspace_root} eq $workspace;
    my %members = map { $_ => 1 } @{$metadata->{workspace_members}};
    my %member_packages = map { $_->{name} => $_ }
        grep { $members{$_->{id}} } @{$metadata->{packages}};
    my %membership;
    my $policy_path = 'ci/cargo-release-groups.json';
    if (-e "$workspace/$policy_path") {
        my $policy = decode_json(read_file("$workspace/$policy_path"));
        die "Invalid release-group policy in $name\n"
            unless ref($policy) eq 'HASH' && ($policy->{schema} // 0) == 1
                && ref($policy->{groups}) eq 'ARRAY' && @{$policy->{groups}};
        for my $group (@{$policy->{groups}}) {
            die "Invalid release group in $name\n"
                unless ref($group) eq 'HASH' && ($group->{name} // '') =~ /^[a-z][a-z0-9-]*$/
                    && ref($group->{members}) eq 'ARRAY' && @{$group->{members}}
                    && $member_packages{$group->{primary} // ''};
            my $key = "$name|$group->{name}";
            die "Duplicate release group $key\n" if exists $groups{$key};
            my $ledger = $group->{changelog} // '';
            die "Invalid group changelog in $key\n"
                    unless $ledger =~ m{^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*(?:/[a-zA-Z0-9_.-]+)*$}
                    && $ledger !~ m{(?:^|/)\.\.(?:/|$)} && -f "$workspace/$ledger";
            my $version = $member_packages{$group->{primary}}{version};
            for my $member (@{$group->{members}}) {
                die "Unknown or duplicate release-group member in $name: $member\n"
                    unless $member_packages{$member} && !exists $membership{$member};
                die "Release-group version mismatch in $key: $member\n"
                    unless $member_packages{$member}{version} eq $version;
                $membership{$member} = $key;
            }
            die "Group primary is not a member in $key\n"
                unless ($membership{$group->{primary}} // '') eq $key;
            $groups{$key} = { %$group, repo => $name, selected_version => $version };
        }
        die "Unassigned release-group member in $name: $_\n"
            for grep { !exists $membership{$_} } sort keys %member_packages;
    }
    my %matched;
    for my $package (@{$metadata->{packages}}) {
        next unless $members{$package->{id}};
        my $path = File::Spec->abs2rel($package->{manifest_path}, $workspace);
        die "Workspace member outside $name: $path\n" if $path =~ m{^\.\./};
        my $key = "$name|cargo:$package->{name}";
        $owner{"cargo:$package->{name}"}{$name} = 1;
        my $native = $name eq 'ic-tooling' || grep { under($path, $_) } @{$repo->{native} // []};
        my $role = $package->{metadata}{'toko-tooling'}{loc}{category} // '';
        my $qualification = $role =~ /\A(?:tests|benchmarks|examples)\z/;
        $nodes{$key} = { name => $package->{name}, repo => $name, native => $native,
            qualification => $qualification, role => $role,
            version => $package->{version},
            group => $membership{$package->{name}} };
        my @selected = grep { under($path, $_) } @{$repo->{paths}};
        $matched{$_} = 1 for @selected;
        next unless @selected;
        next if grep { under($path, $_) } @{$repo->{exclude} // []};
        $selected{$key} = 1;
        push @packages, [$name, $path, $package, $native];
        my $visibility = defined($package->{publish}) && !@{$package->{publish}} ? 'private' : 'publishable';
        push @{$inventory{$name}}, [$package->{name}, $path,
            "$package->{version}; $visibility; " . ($role ? "declared role: $role" : 'role unspecified')];
    }
    die "Catalog selects no member below $name/$_\n" for grep { !$matched{$_} } @{$repo->{paths}};
    die "Catalog selects no packages in $name\n" unless @{$inventory{$name} // []};
    for my $path (@{$repo->{npm} // []}) {
        my $package = decode_json(read_file("$workspace/$path"));
        die "Missing npm name: $name/$path\n" unless $package->{name};
        $owner{"npm:$package->{name}"}{$name} = 1;
        $nodes{"$name|npm:$package->{name}"} = { name => $package->{name}, repo => $name };
        $selected{"$name|npm:$package->{name}"} = 1;
        push @npm, [$name, $path, $package];
        push @{$inventory{$name}}, [$package->{name}, $path, ($package->{version} // 'version unspecified') . '; browser package'];
    }
}
sub dependency {
    my ($repo, $path, $package, $ecosystem, $dependency, $kind, $annotation, $source, $native, $conditional, $selection) = @_;
    my $from = "$repo|$ecosystem:$package";
    my @owners = sort keys %{$owner{"$ecosystem:$dependency"} // {}};
    # Pinned Git dependencies can name packages absent from today's workspace.
    if (defined($source) && $source =~ m{^git\+(?:https://github\.com/|ssh://git\@github\.com/)dragginzgame/([a-z][a-z0-9-]*)(?:\.git)?(?:[?#]|$)}) {
        my $git_owner = $1;
        die "Uncatalogued first-party Git owner: $git_owner\n" unless exists $repos{$git_owner};
        @owners = ($git_owner);
        my $to = "$git_owner|$ecosystem:$dependency";
        unless (exists($nodes{$to})) {
            $nodes{$to} = { name => "$dependency (pinned Git)", repo => $git_owner,
                native => $git_owner eq 'ic-tooling', historical => 1 };
        }
    }
    return unless @owners;
    die "Ambiguous owner for $ecosystem dependency $dependency in $repo/$path\n" if @owners > 1;
    my $to = "$owners[0]|$ecosystem:$dependency";
    return if $to eq $from;
    my $key = "$from\t$to";
    my $qualification = $nodes{$from}{qualification} || $nodes{$to}{qualification};
    my $label = $kind;
    $label .= ', conditional' if $conditional;
    $label .= ', qualification' if $qualification;
    $label .= ', native' if $native || $nodes{$to}{native};
    $edges{$key}{labels}{$label} = 1;
    if ($kind eq 'normal') {
        $edges{$key}{normal} = 1;
        $edges{$key}{solid} = 1 unless $native || $nodes{$to}{native} || $conditional || $qualification;
    }
    $annotation .= ', native package' if $native;
    $annotation .= ', qualification role' if $qualification;
    my $evidence = "[$package](@{[source_link($repo, $path)]}) → `$dependency` ($ecosystem $kind$annotation); " . text_cell($selection);
    $edges{$key}{evidence}{$evidence} = 1;
}
for my $entry (@packages) {
    my ($repo, $path, $package, $native) = @$entry;
    for my $dep (@{$package->{dependencies}}) {
        my $annotation = $dep->{optional} ? ', optional' : '';
        $annotation .= ', target-specific' if defined $dep->{target};
        my $location = $dep->{path} // $dep->{source} // 'registry (Cargo default)';
        $location = 'path:' . File::Spec->abs2rel($location, $parent) if defined $dep->{path};
        my $selection = "requirement=$dep->{req}; declared source=$location; target=" . ($dep->{target} // 'all')
            . '; requested features=' . join(',', @{$dep->{features}})
            . '; default features=' . ($dep->{uses_default_features} ? 'yes' : 'no');
        dependency($repo, $path, $package->{name}, 'cargo', $dep->{name},
            $dep->{kind} // 'normal', $annotation, $dep->{source}, $native,
            $dep->{optional} || defined($dep->{target}), $selection);
    }
}
for my $entry (@npm) {
    my ($repo, $path, $package) = @$entry;
    for my $section (qw(dependencies optionalDependencies peerDependencies devDependencies)) {
        dependency($repo, $path, $package->{name}, 'npm', $_,
            $section eq 'devDependencies' ? 'dev' : 'normal', ", $section", undef, 0,
            $section eq 'optionalDependencies' || $section eq 'peerDependencies',
            "requirement=$package->{$section}{$_}; source/activation unresolved")
            for sort keys %{$package->{$section} // {}};
    }
}

my (%graph, %normal, %declared);
for my $key (sort keys %edges) {
    my ($from, $to) = split /\t/, $key;
    $declared{$from}{$to} = 1;
    $graph{$from}{$to} = 1 if $edges{$key}{solid};
    next unless $edges{$key}{normal};
    $normal{$from}{$to} = 1;
    # Do not let native tooling paths hide direct library/application arrows.
}
sub reachable {
    my ($graph, $start, $goal, $skip) = @_;
    my (%seen, @queue);
    @queue = ($start);
    while (@queue) {
        my $node = shift @queue;
        next if $seen{$node}++;
        for my $next (sort keys %{$graph->{$node} // {}}) {
            next if defined($skip) && "$node\t$next" eq $skip;
            return 1 if $next eq $goal;
            push @queue, $next;
        }
    }
    return 0;
}
my %root_repos = map { $_ => 1 } @{$catalog->{roots}};
my %visible = map { $_ => 1 } keys %selected;
my @pending = sort keys %visible;
while (@pending) {
    my $from = shift @pending;
    for my $to (keys %{$declared{$from} // {}}) {
        push @pending, $to unless $visible{$to}++;
    }
}
sub diagram {
    my ($labels, $normal, $solid, $full) = @_;
    # Reduction is safe on DAGs; retain all edges if a cycle appears.
    my $cyclic = grep { reachable($solid, $_, $_, undef) } keys %$labels;
    my $diagram = "```mermaid\nflowchart TD\n";
    my $declare = sub {
        my ($name, $indent) = @_;
        my $label = $labels->{$name};
        $label =~ s/"/&quot;/g;
        my ($open, $close) = $name =~ /^app:/ ? ('([', '])') : ('[', ']');
        return $indent . node_id($name) . "$open\"$label\"$close\n";
    };
    $diagram .= $declare->($_, '    ') for grep { /^app:/ } sort keys %$labels;
    my %by_repo;
    push @{$by_repo{$nodes{$_}{repo}}}, $_ for grep { !/^app:/ } sort keys %$labels;
    for my $repo (sort keys %by_repo) {
        $diagram .= '    subgraph ' . node_id("repo:$repo") . "[\"$repo\"]\n";
        my %by_group;
        for my $name (@{$by_repo{$repo}}) {
            if (my $group = $nodes{$name}{group}) {
                push @{$by_group{$group}}, $name;
            } else {
                $diagram .= $declare->($name, '        ');
            }
        }
        for my $key (sort keys %by_group) {
            my $group = $groups{$key};
            $diagram .= '        subgraph ' . node_id("group:$key")
                . "[\"$group->{name} · $group->{selected_version}\"]\n";
            $diagram .= $declare->($_, '            ') for @{$by_group{$key}};
            $diagram .= "        end\n";
        }
        $diagram .= "    end\n";
    }
    for my $from (sort keys %$labels) {
        for my $to (sort keys %{$normal->{$from} // {}}) {
            next unless exists $labels->{$to};
            my $native = !$solid->{$from}{$to};
            next if !$full && !$native && !$cyclic && reachable($solid, $from, $to, "$from\t$to");
            my $arrow = $native ? ' -.-> ' : ' --> ';
            if ($full) {
                my $label = join('; ', sort keys %{$edges{"$from\t$to"}{labels}});
                $arrow = $native ? " -. \"$label\" .-> " : " -->|\"$label\"| " if $label ne 'normal';
            }
            $diagram .= '    ' . node_id($from) . $arrow . node_id($to) . "\n";
        }
    }
    return "$diagram```\n";
}
my %labels = map { $_ => $nodes{$_}{name} . ($nodes{$_}{qualification} ? " (qualification: $nodes{$_}{role})" : '') } keys %visible;
my $full_diagram = diagram(\%labels, \%declared, \%graph, 1);

# The README shows application groups and selected library entry points. Walk
# through omitted internal crates, stopping at the next displayed dependency.
# This preserves real package paths rather than merging a workspace's edges.
my %focus = map { $_ => 1 } grep { /\|cargo:/ && !$nodes{$_}{native} && !$nodes{$_}{qualification} } keys %selected;
if (exists $catalog->{overview}) {
    die "Catalog overview must be a nonempty crate-name array\n"
        unless ref($catalog->{overview}) eq 'ARRAY' && @{$catalog->{overview}};
    %focus = ();
    for my $package (@{$catalog->{overview}}) {
        my @owners = sort keys %{$owner{"cargo:$package"} // {}};
        die "Unknown or ambiguous overview crate: $package\n" unless @owners == 1;
        my $key = "$owners[0]|cargo:$package";
        die "Overview crate is not a selected library: $package\n"
            unless $selected{$key} && !$nodes{$key}{native} && !$nodes{$key}{qualification};
        $focus{$key} = 1;
    }
}
my (%overview_labels, %overview, %starts);
for my $repo (@{$catalog->{roots}}) {
    my $key = "app:$repo";
    $overview_labels{$key} = $repo;
    $starts{$key} = [grep { /^\Q$repo\E\|cargo:/ && !$nodes{$_}{native} && !$nodes{$_}{qualification} } sort keys %selected];
}
@pending = sort keys %overview_labels;
while (@pending) {
    my $from = shift @pending;
    my %seen;
    my @queue = map { sort keys %{$graph{$_} // {}} } @{$starts{$from}};
    while (@queue) {
        my $next = shift @queue;
        next if $seen{$next}++;
        my $target = $root_repos{$nodes{$next}{repo}} ? "app:$nodes{$next}{repo}" : $next;
        if ($target ne $from && ($focus{$next} || exists $starts{$target})) {
            $overview{$from}{$target} = 1;
            unless (exists $overview_labels{$target}) {
                $overview_labels{$target} = $nodes{$next}{name};
                $starts{$target} = [$next];
                push @pending, $target;
            }
            next;
        }
        push @queue, sort keys %{$graph{$next} // {}};
    }
}
my $overview_diagram = diagram(\%overview_labels, \%overview, \%overview);
my $details = "## Full package graph\n\nDeclaration inventory, not an active production graph or cycle detector. "
    . "Solid arrows are unconditional normal declarations between non-native, non-qualification packages. "
    . "Labelled dashed arrows retain dev/build, conditional, native and qualification relationships. "
    . "All direct edges are retained here. No target or feature selection was resolved.\n\n"
    . "Coverage: selected Cargo workspace members and catalogued npm files only. "
    . "Generated and independent qualification workspaces are unobserved; no generators were executed. "
    . "Private status alone does not infer a qualification role.\n\n<details>\n<summary>Expand declared package relationships</summary>\n\n"
    . $full_diagram . "\n</details>\n\n## Release groups\n\n"
    . "Local policy and manifest versions; not registry publication or downstream adoption evidence. "
    . "Membership includes private qualification packages omitted from the diagram.\n\n"
    . "Workspace / group | Version | Members | Changelog\n--- | --- | --- | ---\n";
for my $key (sort keys %groups) {
    my $group = $groups{$key};
    $details .= "[$group->{repo} / $group->{name}](@{[source_link($group->{repo}, 'ci/cargo-release-groups.json')]})"
        . " | $group->{selected_version} | " . join(', ', map { "`$_`" } sort @{$group->{members}})
        . " | [Changelog](@{[source_link($group->{repo}, $group->{changelog})]})\n";
}
$details .= "\nWorkspaces without an explicit release-group policy retain repository boundaries only; "
    . "no independent group membership is inferred. Browser packages and historical Git-only packages "
    . "remain outside Cargo release groups.\n\n## Workspace inventory\n\nRepository | Selected packages and manifests\n--- | ---\n";
for my $name (sort keys %repos) {
    $details .= "[$name](https://github.com/dragginzgame/$name) | " . join('<br>',
        map { "[$_->[0]](@{[source_link($name, $_->[1])]}) (" . text_cell($_->[2]) . ")" }
        sort { $a->[0] cmp $b->[0] } @{$inventory{$name}}) . "\n";
}
$details .= "\n## Direct dependency evidence\n\nConsumer package → dependency package | Declarations\n--- | ---\n";
for my $key (sort keys %edges) {
    my ($from, $to) = split /\t/, $key;
    $details .= "$nodes{$from}{name} → $nodes{$to}{name} | " . join('<br>', sort keys %{$edges{$key}{evidence}}) . "\n";
}
my @historical = grep { $nodes{$_}{historical} } sort keys %nodes;
$details .= "\nPinned Git packages absent from their owner's current checkout (no outgoing dependencies inferred): "
    . join(', ', map { "`$nodes{$_}{name}` (`$nodes{$_}{repo}`)" } @historical) . ".\n" if @historical;
my @roots = grep { $root_repos{$nodes{$_}{repo}} } keys %selected;
my @outside = grep {
    my $package = $_;
    !$root_repos{$nodes{$package}{repo}} && !grep { reachable(\%normal, $_, $package, undef) } @roots
} sort keys %selected;
$details .= "\nSelected packages without a normal-dependency path from the application roots: "
    . join(', ', map { "`$nodes{$_}{name}`" } @outside) . ".\n" if @outside;

my @updates;
for my $selection (['README.md', $overview_diagram], ['docs/stack.md', $details]) {
    my ($relative, $generated) = @$selection;
    my $file = "$output_root/$relative";
    die "Refusing symlink output: $file\n" if -l $file;
    my $old = read_file($file);
    my $start = '<!-- stack-graph:start -->';
    my $end = '<!-- stack-graph:end -->';
    die "Expected one generated block in $file\n"
        unless (() = $old =~ /\Q$start\E/g) == 1 && (() = $old =~ /\Q$end\E/g) == 1;
    my $new = $old;
    $new =~ s/\Q$start\E.*?\Q$end\E/$start\n$generated$end/s
        or die "Misordered generated markers in $file\n";
    push @updates, [$file, $new] if $new ne $old;
}
if ($check) {
    die "Stack graph is stale: " . join(', ', map { $_->[0] } @updates) . "; regenerate with --write\n" if @updates;
    print "Stack graph and manifest evidence are current.\n";
} else {
    for my $update (@updates) {
        my ($file, $content) = @$update;
        my ($fh, $temporary) = tempfile('.stack-graph-XXXXXX', DIR => dirname($file), UNLINK => 0);
        print {$fh} $content or die "Cannot write $temporary: $!\n";
        close $fh or die "Cannot close $temporary: $!\n";
        chmod 0644, $temporary or die "Cannot set permissions on $temporary: $!\n";
        rename $temporary, $file or die "Cannot replace $file (prepared $temporary): $!\n";
    }
    print "Updated " . scalar(@updates) . " stack documentation file(s).\n";
}
