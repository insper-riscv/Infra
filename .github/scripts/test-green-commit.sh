#!/usr/bin/env bash
# Tests of green-commit.sh against canned answers of the GitHub API, so the choice of the
# commit (wait for a running one, skip a failed one, accept a re-run) is checked without the
# network:  bash .github/scripts/test-green-commit.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/green-commit.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"

# A stand-in for `gh api`: the list of commits comes from <scenario>/iter<N>/commits and the runs of a
# workflow on a commit from <scenario>/iter<N>/<workflow>/<sha>.json. N counts the polls of the commit
# list, and the last iteration is repeated, so a scenario can describe a run that finishes later.
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
url="$2"
n=$(cat "$SCENARIO/polls" 2> /dev/null || echo 0)
case "$url" in
  repos/*/commits\?*)
    n=$((n + 1)); echo "$n" > "$SCENARIO/polls"
    d="$SCENARIO/iter$n"; [ -d "$d" ] || d="$SCENARIO/iter$(ls "$SCENARIO" | grep -c '^iter')"
    echo "$d" > "$SCENARIO/dir"; cat "$d/commits" ;;
  repos/*/actions/workflows/*/runs\?*)
    wf="${url#*workflows/}"; wf="${wf%%/*}"; sha="${url#*head_sha=}"; sha="${sha%%&*}"
    ev="${url#*event=}"; ev="${ev%%&*}"; ext=json; [ "$ev" = push ] || ext="$ev.json"
    f="$(cat "$SCENARIO/dir")/$wf/$sha.$ext"; if [ -f "$f" ]; then cat "$f"; else echo '[]'; fi ;;
  *) echo "unexpected $url" >&2; exit 1 ;;
esac
GH
chmod +x "$tmp/bin/gh"

now() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }
fail=0

# new_iter <scenario> <n>: the commits (newest first) are given as "sha date" lines on stdin
new_iter() { mkdir -p "$1/iter$2"; cat > "$1/iter$2/commits"; }
# runs <scenario> <n> <workflow> <sha> <json>
runs() { mkdir -p "$1/iter$2/$3"; echo "$5" > "$1/iter$2/$3/$4.json"; }
ok='[{"s":"completed","c":"success"}]'
bad='[{"s":"completed","c":"failure"}]'
running='[{"s":"in_progress","c":null}]'

# run_case <name> <scenario> <expected sha or FAIL> [env...]
run_case() {
  local name="$1" scen="$2" want="$3"; shift 3
  local out rc=0
  out=$(env PATH="$tmp/bin:$PATH" SCENARIO="$scen" POLL_SECONDS=0 SETTLE_MINUTES=10 \
        UPSTREAM_REPO="owner/repo" REQUIRED_WORKFLOWS="ci.yml debug.yml" "$@" bash "$script" 2> "$scen/stderr") || rc=$?
  if [ "$want" = FAIL ]; then
    if [ "$rc" -ne 0 ]; then echo "ok    $name"; else echo "WRONG $name: wanted a failure, got $out"; fail=1; fi
  elif [ "$rc" -eq 0 ] && [ "$out" = "$want" ]; then echo "ok    $name"
  else echo "WRONG $name: wanted $want, got '$out' (exit $rc)"; sed 's/^/        /' "$scen/stderr"; fail=1; fi
}

old="$(now '-5 hours')"; older="$(now '-9 hours')"; fresh="$(now '-2 minutes')"
A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb; C=cccccccccccccccccccccccccccccccccccccccc

# 1. the newest commit is green: it is the one
s="$tmp/s1"; new_iter "$s" 1 <<< "$A $old"$'\n'"$B $older"
runs "$s" 1 ci.yml $A "$ok"; runs "$s" 1 debug.yml $A "$ok"; runs "$s" 1 ci.yml $B "$ok"; runs "$s" 1 debug.yml $B "$ok"
run_case "newest green" "$s" $A

# 2. the newest failed in one workflow: the previous one is taken
s="$tmp/s2"; new_iter "$s" 1 <<< "$A $old"$'\n'"$B $older"
runs "$s" 1 ci.yml $A "$ok"; runs "$s" 1 debug.yml $A "$bad"; runs "$s" 1 ci.yml $B "$ok"; runs "$s" 1 debug.yml $B "$ok"
run_case "newest failed, previous taken" "$s" $B

# 3. the newest is running and finishes green on the next poll: wait for it
s="$tmp/s3"; new_iter "$s" 1 <<< "$A $old"$'\n'"$B $older"; new_iter "$s" 2 <<< "$A $old"$'\n'"$B $older"
runs "$s" 1 ci.yml $A "$ok"; runs "$s" 1 debug.yml $A "$running"; runs "$s" 1 ci.yml $B "$ok"; runs "$s" 1 debug.yml $B "$ok"
runs "$s" 2 ci.yml $A "$ok"; runs "$s" 2 debug.yml $A "$ok"; runs "$s" 2 ci.yml $B "$ok"; runs "$s" 2 debug.yml $B "$ok"
run_case "running, then green: waits" "$s" $A WAIT_MINUTES=5

# 4. the newest is running and finishes failed: the previous one is taken
s="$tmp/s4"; new_iter "$s" 1 <<< "$A $old"$'\n'"$B $older"; new_iter "$s" 2 <<< "$A $old"$'\n'"$B $older"
runs "$s" 1 ci.yml $A "$ok"; runs "$s" 1 debug.yml $A "$running"; runs "$s" 1 ci.yml $B "$ok"; runs "$s" 1 debug.yml $B "$ok"
runs "$s" 2 ci.yml $A "$ok"; runs "$s" 2 debug.yml $A "$bad"; runs "$s" 2 ci.yml $B "$ok"; runs "$s" 2 debug.yml $B "$ok"
run_case "running, then failed: previous" "$s" $B WAIT_MINUTES=5

# 5. the newest never finishes and the wait is over: the previous green one is taken
s="$tmp/s5"; new_iter "$s" 1 <<< "$A $old"$'\n'"$B $older"
runs "$s" 1 ci.yml $A "$ok"; runs "$s" 1 debug.yml $A "$running"; runs "$s" 1 ci.yml $B "$ok"; runs "$s" 1 debug.yml $B "$ok"
run_case "wait over: previous green" "$s" $B WAIT_MINUTES=0

# 6. a re-run that succeeded after a failure counts
s="$tmp/s6"; new_iter "$s" 1 <<< "$A $old"
runs "$s" 1 ci.yml $A "$ok"; runs "$s" 1 debug.yml $A '[{"s":"completed","c":"failure"},{"s":"completed","c":"success"}]'
run_case "re-run that succeeded" "$s" $A

# 7. a commit with no run of a workflow is skipped when old, and waited for when it is a moment old
s="$tmp/s7"; new_iter "$s" 1 <<< "$A $old"$'\n'"$B $older"
runs "$s" 1 ci.yml $A "$ok"; runs "$s" 1 ci.yml $B "$ok"; runs "$s" 1 debug.yml $B "$ok"
run_case "no run on an old commit: skipped" "$s" $B
s="$tmp/s8"; new_iter "$s" 1 <<< "$A $fresh"$'\n'"$B $older"; new_iter "$s" 2 <<< "$A $fresh"$'\n'"$B $older"
runs "$s" 1 ci.yml $B "$ok"; runs "$s" 1 debug.yml $B "$ok"
runs "$s" 2 ci.yml $A "$ok"; runs "$s" 2 debug.yml $A "$ok"; runs "$s" 2 ci.yml $B "$ok"; runs "$s" 2 debug.yml $B "$ok"
run_case "no run yet on a commit pushed a moment ago: waits" "$s" $A WAIT_MINUTES=5

# 9. nothing green in the window: an error
s="$tmp/s9"; new_iter "$s" 1 <<< "$A $old"$'\n'"$C $older"
runs "$s" 1 ci.yml $A "$bad"; runs "$s" 1 ci.yml $C "$bad"
run_case "nothing green" "$s" FAIL

# 10. a merge queue runs the CI on merge_group: the commit has no push run, and counts only when that
# event is listed (a commit with a failed push run and a green merge_group run is green too)
s="$tmp/s10"; new_iter "$s" 1 <<< "$A $old"$'\n'"$B $older"
mkdir -p "$s/iter1/ci.yml" "$s/iter1/debug.yml"
echo "$ok" > "$s/iter1/ci.yml/$A.merge_group.json"; echo "$ok" > "$s/iter1/debug.yml/$A.merge_group.json"
runs "$s" 1 ci.yml $B "$ok"; runs "$s" 1 debug.yml $B "$ok"
run_case "merge_group not listed: skipped" "$s" $B
run_case "merge_group listed: counts" "$s" $A UPSTREAM_EVENTS="push merge_group"
echo "$bad" > "$s/iter1/ci.yml/$A.json"
run_case "failed push, green merge_group, both listed" "$s" $A UPSTREAM_EVENTS="push merge_group"

[ "$fail" -eq 0 ] && echo "all cases passed" || { echo "FAILED"; exit 1; }
