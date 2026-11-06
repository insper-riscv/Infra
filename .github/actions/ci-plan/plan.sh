#!/usr/bin/env bash
# Resolves the CI images (tag latest) and evaluates $GATES (name|image|tokens) in the current git checkout.
# It writes `images` and `gates` (single-line JSON) to $GITHUB_OUTPUT. A gate is skipped only when the digest
# of the image could be read and an artifact named ci-pass-<gate>-<key> exists, is not expired and was
# uploaded by a run of a branch of this same repository (never a fork). Any doubt (the digest cannot be read,
# API error) runs the job. A re-run with "debug logging" (RUNNER_DEBUG=1) and every scheduled or manual run
# never skip.
set -euo pipefail
set -f # the tokens are globs for git, not for the shell

: "${GATES=}" "${GITHUB_REPOSITORY:?}" "${GITHUB_OUTPUT:?}"
owner="${GITHUB_REPOSITORY_OWNER,,}"

images='{}'
for name in ci-vhdl ci-elf ci-act4 dev_tools; do
  images=$(jq -c --arg k "$name" --arg v "ghcr.io/$owner/$name:latest" '. + {($k): $v}' <<< "$images")
done

# The digest that latest has now (anonymous read of a public image); empty when it cannot be read.
resolve_digest() {
  local name="$1" token digest
  token=$(curl -fsS --max-time 20 "https://ghcr.io/token?scope=repository:$owner/$name:pull" | jq -r '.token // empty') || return 1
  [ -n "$token" ] || return 1
  digest=$(curl -fsSI --max-time 20 -H "Authorization: Bearer $token" \
    -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
    "https://ghcr.io/v2/$owner/$name/manifests/latest" | tr -d '\r' | awk -F': ' 'tolower($1) == "docker-content-digest" { print $2 }') || return 1
  [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || return 1
  echo "$digest"
}

never_skip=false
case "${GITHUB_EVENT_NAME:-}" in schedule|workflow_dispatch) never_skip=true ;; esac
[ "${RUNNER_DEBUG:-0}" = 1 ] && never_skip=true

gates='{}'
while IFS='|' read -r gate image tokens; do
  gate="${gate//[[:space:]]/}"; image="${image//[[:space:]]/}"
  [ -n "$gate" ] || continue
  ref=$(jq -r --arg i "$image" '.[$i] // empty' <<< "$images")
  [ -n "$ref" ] || { echo "::error::gate $gate: image '$image' is not one of the CI images"; exit 1; }
  digest=$(resolve_digest "$image" || true)
  specs=(); includes=0
  for token in $tokens; do
    case "$token" in
      '!'*) specs+=(":(exclude,glob)${token#!}") ;;
      *)    specs+=("$token"); includes=$((includes + 1)) ;;
    esac
  done
  [ "$includes" -gt 0 ] || specs=(. "${specs[@]}")
  # the index entries: "mode object stage<TAB>path"; a submodule is mode 160000 and its commit
  key=$({ echo "gate=$gate"; echo "image=$ref@${digest:-unresolved}"; git ls-files -s -- "${specs[@]}"; } | sha256sum | cut -c1-40)
  artifact="ci-pass-$gate-$key"
  skip=false
  if [ "$never_skip" = false ] && [ -n "$digest" ]; then
    found=$(gh api "repos/$GITHUB_REPOSITORY/actions/artifacts?name=$artifact&per_page=30" \
      --jq '[.artifacts[] | select(.expired == false and .workflow_run.repository_id == .workflow_run.head_repository_id)] | length' \
      2>/dev/null) || found=0
    [[ "$found" =~ ^[0-9]+$ ]] || found=0
    if [ "$found" -gt 0 ]; then
      skip=true
      echo "::notice::gate $gate: reusing the pass of the same inputs ($artifact)."
    fi
  fi
  echo "gate $gate: image ${digest:-unresolved} key $key skip=$skip"
  gates=$(jq -c --arg g "$gate" --arg k "$key" --arg a "$artifact" --arg s "$skip" \
    '. + {($g): {key: $k, artifact: $a, skip: $s}}' <<< "$gates")
done <<< "$GATES"

echo "images=$images" >> "$GITHUB_OUTPUT"
echo "gates=$gates" >> "$GITHUB_OUTPUT"
