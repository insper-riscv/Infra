#!/usr/bin/env bash
# Functions for the plan stages of ci-images.yml, to be sourced.
#
# version_of <repository url> <commit> prints the version of the release whose tag points at the
# commit (the highest one, without the v or Yices-/yices- prefix: the Yices upstream names its tags with a
# capital Y up to 2.6.5 and in lower case from 2.7.0), and nothing when no release tag does.
#
# name_of <repository url> <commit> prints how a component is named in a tag: that version, or the
# first 7 characters of the commit when there is none (Spike, Sail, GTKWave and ACT4 follow a
# branch, and a commit of the GCC that is not a dated release has no version either).
version_of() {
  local tag
  tag=$(git ls-remote --tags "$1" 2>/dev/null \
        | awk -v c="$2" '$1 == c { sub("refs/tags/", "", $2); sub(/\^\{\}$/, "", $2); print $2 }' \
        | grep -E '^(v|[Yy]ices-)?[0-9]+(\.[0-9]+)+$' | sort -V | tail -n 1) || true
  if [ -n "$tag" ]; then printf '%s' "${tag#v}" | sed 's/^[Yy]ices-//'; fi
}

name_of() {
  local version
  version=$(version_of "$1" "$2")
  if [ -n "$version" ]; then printf '%s' "$version"; else printf '%s' "${2:0:7}"; fi
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

# release_of <repository url> <commit> prints the release the commit belongs to: the version of the release whose
# tag points at it (as version_of does) or, for a commit between releases, the nearest earlier release tag with
# -dev (v1.1.0 becomes 1.1.0-dev), and nothing when the repository has no release tag. It fetches only the
# commits and the tags, without file contents.
release_of() {
  local v dir
  v=$(version_of "$1" "$2")
  if [ -n "$v" ]; then printf '%s' "$v"; return 0; fi
  dir=$(mktemp -d)
  git -C "$dir" init -q
  v=$(git -C "$dir" fetch -q --filter=tree:0 --tags "$1" "$2" 2>/dev/null \
      && git -C "$dir" describe --tags --abbrev=0 --match 'v[0-9]*' --match '[0-9]*' FETCH_HEAD 2>/dev/null) || true
  rm -rf "$dir"
  if [ -n "$v" ]; then printf '%s-dev' "${v#v}"; fi
}

# release_date_of <repository url> <commit> prints the date of the release the commit is, which a release
# named for its date (riscv-gnu-toolchain: 2026.10.29) gives by its tag (2026-10-29), and otherwise the date of the
# commit (commit_date, below). The tag date is the day the release was published, and can be later than the commit.
release_date_of() {
  local v
  v=$(version_of "$1" "$2")
  case "$v" in
    [0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]) printf '%s' "${v//./-}" ;;
    *) commit_date "$1" "$2" ;;
  esac
}

# gcc_version_of <riscv-gnu-toolchain commit> prints the version of the GCC the commit bundles: the BASE-VER of the
# commit the gcc submodule points to (16.1.0), with -dev when that commit is not the one of the releases/gcc-<version>
# tag, as it is for a snapshot of the development branch. It needs GH_TOKEN, and prints nothing when the lookup fails.
gcc_version_of() {
  local info sub url repo ver released
  info=$(gh api "repos/riscv-collab/riscv-gnu-toolchain/contents/gcc?ref=$1" \
         --jq '"\(.sha) \(.submodule_git_url)"' 2>/dev/null) || return 0
  sub=${info%% *}; url=${info#* }; repo=${url#https://github.com/}; repo=${repo%.git}
  [ -n "$sub" ] && [ -n "$repo" ] || return 0
  ver=$(curl -fsSL "https://raw.githubusercontent.com/$repo/$sub/gcc/BASE-VER" 2>/dev/null | head -n 1) || true
  [ -n "$ver" ] || return 0
  released=$(git ls-remote --tags "https://github.com/$repo" "refs/tags/releases/gcc-$ver" "refs/tags/releases/gcc-$ver^{}" 2>/dev/null \
             | awk -v c="$sub" '$1 == c { print $1 }' | head -n 1) || true
  if [ -n "$released" ]; then printf '%s' "$ver"; else printf '%s-dev' "$ver"; fi
}

# describe_of <repository url> <commit> prints how the summaries show a component: "<version> <date> (<commit>)",
# the version of the release whose tag points at the commit (left out when none does), the date of the commit and its
# first 7 characters, the same as the second line of the .tag of its image.
describe_of() {
  local v d
  v=$(version_of "$1" "$2")
  d=$(commit_date "$1" "$2")
  printf '%s%s (%s)' "${v:+$v }" "$d" "${2:0:7}"
}
