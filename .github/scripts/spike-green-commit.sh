#!/usr/bin/env bash
# Prints the commit of riscv-isa-sim to build: the latest commit of its default branch on which the
# upstream workflows we depend on succeeded. Spike has no recent release (the last is v1.1.0, from
# 2021), and its branch moves every day, so the image takes a commit its own CI vouches for.
#
# For each recent commit, newest first, every workflow in REQUIRED_WORKFLOWS is looked up on that
# commit (the push run):
#
#   green    all succeeded                     -> this is the commit
#   failed   one of them failed                -> skip it, look at the previous commit
#   pending  one is queued or running          -> a newer commit may still turn green: wait
#   none     one never ran, for a commit older -> skip it (nothing vouches for it)
#            than SETTLE_MINUTES
#
# While a commit newer than the one found is pending, the script waits (polling every
# POLL_SECONDS) for up to WAIT_MINUTES, then settles for the newest green one it has. The commit is
# the only thing written to stdout; the reasoning goes to stderr (and to the step summary).
#
# Environment: GH_TOKEN (the gh CLI), and optionally UPSTREAM_REPO, UPSTREAM_BRANCH,
# REQUIRED_WORKFLOWS, WAIT_MINUTES, POLL_SECONDS, SETTLE_MINUTES and DEPTH.
set -euo pipefail

repo="${UPSTREAM_REPO:-riscv-software-src/riscv-isa-sim}"
branch="${UPSTREAM_BRANCH:-master}"
workflows="${REQUIRED_WORKFLOWS:-continuous-integration.yml debug-smoke.yml}"
wait_minutes="${WAIT_MINUTES:-60}"
poll_seconds="${POLL_SECONDS:-60}"
settle_minutes="${SETTLE_MINUTES:-10}"
depth="${DEPTH:-30}"

log() { echo "$*" >&2; }

# state_of <sha> <age in seconds>: green, failed, pending or none
state_of() {
  local sha="$1" age="$2" failed=0 pending=0 none=0 wf runs
  for wf in $workflows; do
    runs=$(gh api "repos/$repo/actions/workflows/$wf/runs?head_sha=$sha&event=push&per_page=20" \
             --jq '[.workflow_runs[] | {s: .status, c: .conclusion}]')
    if jq -e 'any(.[]; .c == "success")' <<< "$runs" > /dev/null; then
      continue                                   # a re-run that succeeded counts
    elif jq -e 'any(.[]; .s != "completed")' <<< "$runs" > /dev/null; then
      pending=1
    elif jq -e 'length == 0' <<< "$runs" > /dev/null; then
      none=1
    else
      failed=1
    fi
  done
  if   [ "$failed" = 1 ]; then echo failed
  elif [ "$pending" = 1 ]; then echo pending
  elif [ "$none" = 1 ]; then
    # a commit pushed a moment ago may not have its runs yet
    if [ "$age" -lt $((settle_minutes * 60)) ]; then echo pending; else echo none; fi
  else echo green
  fi
}

deadline=$(( $(date +%s) + wait_minutes * 60 ))
while true; do
  commits=$(gh api "repos/$repo/commits?sha=$branch&per_page=$depth" \
              --jq '.[] | "\(.sha) \(.commit.committer.date)"')
  chosen=""; waiting=""; report=""
  while read -r sha date; do
    age=$(( $(date +%s) - $(date -d "$date" +%s) ))
    st=$(state_of "$sha" "$age")
    report+="${sha:0:7} ${date:0:16} $st"$'\n'
    if [ "$st" = green ]; then chosen="$sha"; break; fi
    if [ "$st" = pending ]; then waiting="${sha:0:7}"; fi
  done <<< "$commits"

  if [ -n "$waiting" ] && [ "$(date +%s)" -lt "$deadline" ]; then
    log "commit $waiting is still running its workflows; checking again in ${poll_seconds}s"
    sleep "$poll_seconds"
    continue
  fi
  break
done

if [ -z "$chosen" ]; then
  log "no commit among the last $depth of $repo@$branch has all of: $workflows"
  log "$report"
  exit 1
fi

log "workflows required: $workflows"
log "$report"
log "chosen: ${chosen:0:7}${waiting:+ (the newer commit $waiting did not finish in ${wait_minutes} minutes)}"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Spike commit"
    echo "Required upstream workflows: \`$workflows\`"
    echo
    echo '```'; echo "$report"; echo '```'
    echo "Chosen: \`$chosen\`"
  } >> "$GITHUB_STEP_SUMMARY"
fi
echo "$chosen"
