#!/usr/bin/env bash
# Defines name_of <repository url> <commit>, to be sourced by the plan stages of ci-images.yml.
# It prints how a component is named in a tag: the version of the release whose tag points at the
# commit (the highest one, without the v or Yices- prefix), or the first 7 characters of the commit
# when none does (Spike, Sail, GTKWave and ACT4 follow a branch, and a commit of the GCC that is not
# a dated release has no version either).
name_of() {
  local tag
  tag=$(git ls-remote --tags "$1" 2>/dev/null \
        | awk -v c="$2" '$1 == c { sub("refs/tags/", "", $2); sub(/\^\{\}$/, "", $2); print $2 }' \
        | grep -E '^(v|Yices-)?[0-9]+(\.[0-9]+)+$' | sort -V | tail -n 1) || true
  if [ -n "$tag" ]; then printf '%s' "${tag#v}" | sed 's/^Yices-//'; else printf '%s' "${2:0:7}"; fi
}
