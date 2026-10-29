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

my $catalog = decode_json(read_file($catalog_file));
die "Catalog needs nonempty roots and repositories\n"
    unless ref($catalog) eq 'HASH' && ref($catalog->{roots}) eq 'ARRAY' && @{$catalog->{roots}}
        && ref($catalog->{repositories}) eq 'ARRAY' && @{$catalog->{repositories}};
my (%workspaces, %owner, %nodes, %selected, @packages, @npm, %edges, %inventory);
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
    my %matched;
    for my $package (@{$metadata->{packages}}) {
        next unless $members{$package->{id}};
        my $path = File::Spec->abs2rel($package->{manifest_path}, $workspace);
        die "Workspace member outside $name: $path\n" if $path =~ m{^\.\./};
        my $key = "$name|cargo:$package->{name}";
        $owner{"cargo:$package->{name}"}{$name} = 1;
        my $native = $name eq 'ic-tooling' || grep { under($path, $_) } @{$repo->{native} // []};
        $nodes{$key} = { name => $package->{name}, repo => $name, native => $native };
        my @selected = grep { under($path, $_) } @{$repo->{paths}};
        $matched{$_} = 1 for @selected;
        next unless @selected;
        next if grep { under($path, $_) } @{$repo->{exclude} // []};
        $selected{$key} = 1;
        push @packages, [$name, $path, $package, $native];
        push @{$inventory{$name}}, [$package->{name}, $path];
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
        push @{$inventory{$name}}, [$package->{name}, $path];
    }
}
sub dependency {
    my ($repo, $path, $package, $ecosystem, $dependency, $kind, $annotation, $source, $native) = @_;
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
    if ($kind eq 'normal') {
        $edges{$key}{normal} = 1;
        $edges{$key}{solid} = 1 unless $native || $nodes{$to}{native};
    }
    $annotation .= ', native package' if $native;
    my $evidence = "[$package](@{[source_link($repo, $path)]}) → `$dependency` ($ecosystem $kind$annotation)";
    $edges{$key}{evidence}{$evidence} = 1;
}
for my $entry (@packages) {
    my ($repo, $path, $package, $native) = @$entry;
    for my $dep (@{$package->{dependencies}}) {
        my $annotation = $dep->{optional} ? ', optional' : '';
        $annotation .= ', target-specific' if defined $dep->{target};
        dependency($repo, $path, $package->{name}, 'cargo', $dep->{name},
            $dep->{kind} // 'normal', $annotation, $dep->{source}, $native);
    }
}
for my $entry (@npm) {
    my ($repo, $path, $package) = @$entry;
    for my $section (qw(dependencies optionalDependencies peerDependencies devDependencies)) {
        dependency($repo, $path, $package->{name}, 'npm', $_,
            $section eq 'devDependencies' ? 'dev' : 'normal', ", $section")
            for sort keys %{$package->{$section} // {}};
    }
}

my (%graph, %normal);
for my $key (sort keys %edges) {
    my ($from, $to) = split /\t/, $key;
    next unless $edges{$key}{normal};
    $normal{$from}{$to} = 1;
    # Do not let native tooling paths hide direct library/application arrows.
    $graph{$from}{$to} = 1 if $edges{$key}{solid};
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
my %visible = map { $_ => 1 } grep { $root_repos{$nodes{$_}{repo}} } keys %selected;
my @pending = sort keys %visible;
while (@pending) {
    my $from = shift @pending;
    for my $to (keys %{$normal{$from} // {}}) {
        push @pending, $to unless $visible{$to}++;
    }
}
sub diagram {
    my ($labels, $normal, $solid) = @_;
    # Reduction is safe on DAGs; retain all edges if a cycle appears.
    my $cyclic = grep { reachable($solid, $_, $_, undef) } keys %$labels;
    my $diagram = "```mermaid\nflowchart TD\n";
    for my $name (sort keys %$labels) {
        my $label = $labels->{$name};
        $label =~ s/"/&quot;/g;
        my ($open, $close) = $name =~ /^app:/ ? ('([', '])') : ('[', ']');
        $diagram .= '    ' . node_id($name) . "$open\"$label\"$close\n";
    }
    for my $from (sort keys %$labels) {
        for my $to (sort keys %{$normal->{$from} // {}}) {
            my $native = !$solid->{$from}{$to};
            next if !$native && !$cyclic && reachable($solid, $from, $to, "$from\t$to");
            $diagram .= '    ' . node_id($from) . ($native ? ' -.-> ' : ' --> ') . node_id($to) . "\n";
        }
    }
    return "$diagram```\n";
}
my %labels = map { $_ => $nodes{$_}{name} } keys %visible;
my $full_diagram = diagram(\%labels, \%normal, \%graph);

# The README shows application groups and selected library entry points. Walk
# through omitted internal crates, stopping at the next displayed dependency.
# This preserves real package paths rather than merging a workspace's edges.
my %focus = map { $_ => 1 } grep { /\|cargo:/ && !$nodes{$_}{native} } keys %selected;
if (exists $catalog->{overview}) {
    die "Catalog overview must be a nonempty crate-name array\n"
        unless ref($catalog->{overview}) eq 'ARRAY' && @{$catalog->{overview}};
    %focus = ();
    for my $package (@{$catalog->{overview}}) {
        my @owners = sort keys %{$owner{"cargo:$package"} // {}};
        die "Unknown or ambiguous overview crate: $package\n" unless @owners == 1;
        my $key = "$owners[0]|cargo:$package";
        die "Overview crate is not a selected library: $package\n"
            unless $selected{$key} && !$nodes{$key}{native};
        $focus{$key} = 1;
    }
}
my (%overview_labels, %overview, %starts);
for my $repo (@{$catalog->{roots}}) {
    my $key = "app:$repo";
    $overview_labels{$key} = $repo;
    $starts{$key} = [grep { /^\Q$repo\E\|cargo:/ && !$nodes{$_}{native} } sort keys %selected];
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
my $details = "## Full package graph\n\n<details>\n<summary>Expand all crates, browser packages and native tools</summary>\n\n"
    . $full_diagram . "\n</details>\n\n## Workspace inventory\n\nRepository | Selected packages and manifests\n--- | ---\n";
for my $name (sort keys %repos) {
    $details .= "[$name](https://github.com/dragginzgame/$name) | " . join('<br>',
        map { "[$_->[0]](@{[source_link($name, $_->[1])]})" }
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
my @outside = grep { !$visible{$_} } sort keys %selected;
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
