#!/usr/bin/env bash
# Source-only observation; no repair, rendering, fetching or release authority.
# Shared companions: scripts/ci/cargo-release-groups.jq
set -euo pipefail
[[ $# == 1 && ( "$1" == policy || "$1" == observe ) ]] || {
    echo 'usage: observe-cargo-release-bootstrap.sh policy|observe' >&2; exit 2;
}
script_dir="$(cd -P "${BASH_SOURCE[0]%/*}" && pwd -P)"
policy="$(jq -e -L "$script_dir" 'include "cargo-release-groups"; release_policy' ci/cargo-release-groups.json)"
if [[ "$1" == policy ]]; then printf '%s\n' "$policy"; exit 0; fi
# Cargo owns workspace discovery without resolving the incoherent local lock.
# Both interruption orders may be observed. The caller owns exact input custody
# and must re-observe after helpers/effects; this output is never a cached proof.
metadata="$(cargo metadata --no-deps --offline --format-version 1)"
catalog="$("${YQ:-yq}" -p toml -o json '.' Cargo.toml)"
lock="$("${YQ:-yq}" -p toml -o json '.' Cargo.lock)"
jq -n -e -L "$script_dir" --argjson policy "$policy" --argjson metadata "$metadata" \
    --argjson catalog "$catalog" --argjson lock "$lock" '
  include "cargo-release-groups";
  $metadata as $m |
  [$m.packages[] | select(.id as $id | $m.workspace_members | index($id))] as $owned |
  if ($catalog | has("package")) or ($catalog.workspace | type) != "object" or
     $catalog.workspace.package.version != null or
     any($policy.groups[]; .version != "package") or
     ($owned | length) == 0 or
     ($owned | map(.id) | sort) != ($m.workspace_members | sort) or
     ($owned | map(.name) | sort) != ([$policy.groups[].members[]] | sort) or
     any($owned[]; .source != null or (.version | stable | not))
  then error("bootstrap observation requires a virtual package-version workspace") else . end |
  [$lock.package[] | select(.source == null)] as $local |
  if ($local | map(.name) | sort) != ($owned | map(.name) | sort) or
     any($local[]; (.version | stable | not))
  then error("invalid bootstrap local lock identities") else . end |
  member_catalog($catalog; $owned) as $dependencies |
  if ($dependencies | map(.package) | unique | sort) != ($owned | map(.name) | sort) or
     any($dependencies[]; (.value.path | type) != "string" or (.value.version | type) != "string" or
       (.value.version | sub("^[~^=]?[ \t]*"; "") | stable | not)) or
     any($policy.groups[]; . as $g |
       ([$dependencies[] | select(.package as $n | $g.members | index($n)) | .key] | sort) != ($g.dependencies | sort))
  then error("invalid bootstrap member dependency catalog") else . end |
  {version:"unchanged", dependencies:[$dependencies[] as $d |
      $local[] | select(.name == $d.package) |
      {alias:$d.key, previous:$d.value.version, next:.version}]} as $catalog_edit |
  [$policy.groups[] as $g |
    [$g.members[] as $name |
      ($owned | map(select(.name == $name))[0]) as $p |
      ($local | map(select(.name == $name))[0]) as $l |
      if ($p.manifest_path | startswith($m.workspace_root + "/") | not)
      then error("bootstrap member outside workspace") else
      {name:$name, manifest:$p.manifest_path, declared:$p.version, locked:$l.version} end] as $members |
    if ($members | map(.locked) | unique | length) != 1
    then error("bootstrap group lock versions differ")
    else {name:$g.name, primary:$g.primary, members:$members} end] as $groups |
  {schema:1, workspace_root:$m.workspace_root, target_directory:$m.target_directory,
   coherent:all($groups[].members[]; .declared == .locked), groups:$groups, catalog_edit:$catalog_edit}'
