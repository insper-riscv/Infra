#!/usr/bin/env bash
# Functions for the plan stages of ci-images.yml, to be sourced.
#
# name_of <repository url> <commit> prints how a component is named in a tag: the version of the
# release whose tag points at the commit (the highest one, without the v or Yices- prefix), or the
# first 7 characters of the commit when none does (Spike, Sail, GTKWave and ACT4 follow a branch,
# and a commit of the GCC that is not a dated release has no version either).
name_of() {
  local tag
  tag=$(git ls-remote --tags "$1" 2>/dev/null \
        | awk -v c="$2" '$1 == c { sub("refs/tags/", "", $2); sub(/\^\{\}$/, "", $2); print $2 }' \
        | grep -E '^(v|Yices-)?[0-9]+(\.[0-9]+)+$' | sort -V | tail -n 1) || true
  if [ -n "$tag" ]; then printf '%s' "${tag#v}" | sed 's/^Yices-//'; else printf '%s' "${2:0:7}"; fi
}

# Defines commit_date <repository url> <commit>, which prints the committer date of the commit
# (YYYY-MM-DD, in the time zone the commit records), the same date `git log -1 --format=%cs` gives
# in the image that builds that commit. It fetches only the commit, without file contents.
commit_date() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" fetch -q --depth 1 --filter=blob:none "$1" "$2" 2>/dev/null \
    && git -C "$dir" log -1 --format=%cs FETCH_HEAD
  rm -rf "$dir"
}
