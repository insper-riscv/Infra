#!/usr/bin/env bash
# Reads $LOCK (image=sha256:digest) and evaluates $GATES (name|image|tokens) in the current git checkout.
# It writes `images` and `gates` (single-line JSON) to $GITHUB_OUTPUT. A gate is skipped only when an
# artifact named ci-pass-<gate>-<key> exists, is not expired and was uploaded by a run of a branch of
# this same repository (never a fork). Any doubt (no lock entry, API error) runs the job.
# A re-run with "debug logging" (RUNNER_DEBUG=1) and every scheduled or manual run never skip.
set -euo pipefail
set -f # the tokens are globs for git, not for the shell

: "${LOCK:?}" "${GATES=}" "${GITHUB_REPOSITORY:?}" "${GITHUB_OUTPUT:?}"
owner="${GITHUB_REPOSITORY_OWNER,,}"

[ -f "$LOCK" ] || { echo "::error::$LOCK does not exist: it holds the digests of the CI images"; exit 1; }
images='{}'
while IFS='=' read -r name digest; do
  case "$name" in ''|'#'*) continue ;; esac
  [[ "$name" =~ ^[a-z0-9_-]+$ ]] || { echo "::error::$LOCK: bad image name '$name'"; exit 1; }
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "::error::$LOCK: bad digest for $name"; exit 1; }
  images=$(jq -c --arg k "$name" --arg v "ghcr.io/$owner/$name@$digest" '. + {($k): $v}' <<< "$images")
done < "$LOCK"

never_skip=false
case "${GITHUB_EVENT_NAME:-}" in schedule|workflow_dispatch) never_skip=true ;; esac
[ "${RUNNER_DEBUG:-0}" = 1 ] && never_skip=true

gates='{}'
while IFS='|' read -r gate image tokens; do
  gate="${gate//[[:space:]]/}"; image="${image//[[:space:]]/}"
  [ -n "$gate" ] || continue
  ref=$(jq -r --arg i "$image" '.[$i] // empty' <<< "$images")
  [ -n "$ref" ] || { echo "::error::gate $gate: image '$image' is not in $LOCK"; exit 1; }
  specs=(); includes=0
  for token in $tokens; do
    case "$token" in
      '!'*) specs+=(":(exclude,glob)${token#!}") ;;
      *)    specs+=("$token"); includes=$((includes + 1)) ;;
    esac
  done
  [ "$includes" -gt 0 ] || specs=(. "${specs[@]}")
  # the index entries: "mode object stage<TAB>path"; a submodule is mode 160000 and its commit
  key=$({ echo "gate=$gate"; echo "image=$ref"; git ls-files -s -- "${specs[@]}"; } | sha256sum | cut -c1-40)
  artifact="ci-pass-$gate-$key"
  skip=false
  if [ "$never_skip" = false ]; then
    found=$(gh api "repos/$GITHUB_REPOSITORY/actions/artifacts?name=$artifact&per_page=30" \
      --jq '[.artifacts[] | select(.expired == false and .workflow_run.repository_id == .workflow_run.head_repository_id)] | length' \
      2>/dev/null || echo 0)
    if [ "${found:-0}" -gt 0 ]; then
      skip=true
      echo "::notice::gate $gate: reusing the pass of the same inputs ($artifact)."
    fi
  fi
  echo "gate $gate: key $key skip=$skip"
  gates=$(jq -c --arg g "$gate" --arg k "$key" --arg a "$artifact" --arg s "$skip" \
    '. + {($g): {key: $k, artifact: $a, skip: $s}}' <<< "$gates")
done <<< "$GATES"

echo "images=$images" >> "$GITHUB_OUTPUT"
echo "gates=$gates" >> "$GITHUB_OUTPUT"
