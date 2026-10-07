#!/usr/bin/env bash
# Deletes the old versions of the container packages, keeping only what the tag `latest` reaches:
# the manifest tagged `latest` and every manifest below it (the image of each architecture and its
# attestation). Those children have no tag of their own and are what keeps `latest` pullable, so
# they are kept; everything else, tagged or not, is deleted.
#
# It only prints what it would delete, unless called with --delete. A version younger than
# MIN_AGE_MINUTES (default 120) is never deleted: a publication pushes the image of each
# architecture without a tag and only at the end tags the manifest above them, so a young version
# may be one that a publication in progress is about to use. Needs the GitHub CLI, jq and
# docker (buildx), and a token that can delete packages (the delete:packages scope, or the
# packages: write permission of a workflow in this repository).
#
#   scripts/cleanup-images.sh                          every package, only listing
#   scripts/cleanup-images.sh infra-gcc dev_tools      only these, only listing
#   scripts/cleanup-images.sh --delete infra-gcc       really deletes
set -euo pipefail

ORG="${ORG:-insper-riscv}"
MIN_AGE_MINUTES="${MIN_AGE_MINUTES:-120}"
CUTOFF=$(date -u -d "-${MIN_AGE_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ)
ALL_PACKAGES=(infra-ghdl infra-gcc infra-spike infra-gtkwave infra-toolchain dev_tools)
DELETE=false
packages=()
for arg in "$@"; do
  case "$arg" in
    --delete) DELETE=true ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) packages+=("$arg") ;;
  esac
done
[ "${#packages[@]}" -gt 0 ] || packages=("${ALL_PACKAGES[@]}")

# every digest below a manifest: its children, and theirs when a child is an index too. A child that
# is no longer in the registry (something deleted it) is reported, and kept in the list: it is not
# a version that exists, so there is nothing to delete.
children() {
  local image="$1" depth="${2:-0}" raw sub child
  [ "$depth" -lt 4 ] || { echo "manifest tree too deep: $image" >&2; return 1; }
  raw=$(docker buildx imagetools inspect "$image" --raw) || return 1
  jq -r '.manifests[]?.digest' <<< "$raw" | while read -r digest; do
    [ -n "$digest" ] || continue
    echo "$digest"
    sub="${image%%@*}@$digest"
    if ! child=$(docker buildx imagetools inspect "$sub" --raw 2>/dev/null); then
      echo "  warning: ${digest:0:19} is referenced but is not in the registry" >&2
      continue
    fi
    # an index has "manifests"; an image does not, and has nothing below it to follow
    if jq -e '.manifests' <<< "$child" > /dev/null 2>&1; then
      children "$sub" $((depth + 1))
    fi
  done
}

status=0
for package in "${packages[@]}"; do
  echo "== $package"
  image="ghcr.io/$ORG/$package"
  versions=$(gh api --paginate "orgs/$ORG/packages/container/$package/versions?per_page=100") || { echo "  cannot list the versions"; status=1; continue; }
  # --paginate prints one JSON array per page; join them
  versions=$(jq -s 'add' <<< "$versions")

  latest=$(jq -r '[.[] | select(.metadata.container.tags | index("latest"))][0].name // empty' <<< "$versions")
  if [ -z "$latest" ]; then
    echo "  no version has the tag latest: nothing is deleted from this package"
    status=1
    continue
  fi
  if ! below=$(children "$image@$latest"); then
    echo "  cannot read what latest reaches: nothing is deleted from this package"
    status=1
    continue
  fi
  keep=$( { echo "$latest"; echo "$below"; } | sort -u)
  kept=$(jq -r --arg keep "$keep" '($keep | split("\n")) as $k | [.[] | select([.name] | inside($k))] | length' <<< "$versions")
  echo "  keeps $kept versions (latest = ${latest:0:19}, and what is below it)"

  # versions that are not kept: "id<TAB>digest<TAB>tags<TAB>created"
  doomed=$(jq -r --arg keep "$keep" --arg cutoff "$CUTOFF" '
      ($keep | split("\n")) as $k
      | .[] | select([.name] | inside($k) | not) | select(.created_at < $cutoff)
      | [.id, .name[0:19], (.metadata.container.tags | join(",")), .created_at[0:16]] | @tsv' <<< "$versions")
  if [ -z "$doomed" ]; then
    echo "  nothing to delete"
    continue
  fi
  echo "$doomed" | awk -F'\t' '{printf "  %s  %s  %s  tags=[%s]\n", ($0 ? "delete" : ""), $4, $2, $3}'
  if [ "$DELETE" = true ]; then
    while IFS=$'\t' read -r id _; do
      gh api -X DELETE "orgs/$ORG/packages/container/$package/versions/$id" > /dev/null && echo "  deleted version $id"
    done <<< "$doomed"
  else
    echo "  (only listing: run with --delete to delete)"
  fi
done
exit "$status"
