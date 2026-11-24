#!/usr/bin/env bash
# Function for the summaries of ci-images.yml, to be sourced.
#
# summary_row <component> <"[version ]date (commit)"> prints the row of a summary table with the version,
# the date and the commit of a component in columns of their own, from the text describe_of (name-of.sh)
# and the summaries build ("0.71 2026-11-12 (b4c586f)", or "2026-11-22 (ae12eee)" with no version). A text of
# another shape goes whole in the version column.
summary_row() {
  local version date commit
  if [[ $2 =~ ^(.*[^[:space:]])?[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2})\ \(([0-9a-f]+)\)$ ]]; then
    version=${BASH_REMATCH[1]}; date=${BASH_REMATCH[2]}; commit=${BASH_REMATCH[3]}
  else
    version=$2; date=""; commit=""
  fi
  printf '| %s | %s | %s | %s |\n' "$1" "$version" "$date" "${commit:+\`$commit\`}"
}
