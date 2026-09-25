#!/usr/bin/env bash
# Fails if any Argo CD Application pairs RespectIgnoreDifferences=true with
# an ignoreDifferences path that reaches inside an array on a custom
# resource. That pairing does not merely hide a field from the diff, it
# silently discards every update to the object.
#
# The mechanism, because it is not obvious from the option's name:
# RespectIgnoreDifferences rewrites the manifest before the apply. Argo
# strips the ignored paths out of the live object, diffs the stripped copy
# against live to recover their values, and applies that patch onto the
# manifest from git. For a built-in kind the patch is a strategic merge
# patch, which merges arrays by their merge key, so only the ignored field
# comes back. For a custom resource Argo has no strategic-merge schema, so
# it falls back to an RFC 7386 JSON merge patch, and a JSON merge patch
# replaces a differing array wholesale. Ignore one field inside an array and
# the entire array returns from the cluster and overwrites git's.
#
# What that looks like in practice: creates land, every later edit is
# dropped, the apply truthfully logs "unchanged" because the manifest really
# is identical to live by the time it is sent, and the app reports
# "successfully synced" while sitting OutOfSync forever. It cost this repo a
# week of policy edits that never reached the cluster.
#
# Limitation worth stating: a path naming a whole array without brackets
# (.spec.rules rather than .spec.rules[]) is dangerous for the same reason
# and cannot be told apart from a scalar without the CRD schema. The bracket
# form is what the failing config actually used.
set -euo pipefail

ROOT="${ROOT:-platform/argocd}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*"; exit 1; }

[ -d "${ROOT}" ] ||
  fail "${ROOT} not found. If the Argo CD manifests moved, update ROOT here and in ci.yml."

for tool in yq jq; do
  command -v "${tool}" >/dev/null 2>&1 || fail "${tool} is required but not on PATH."
done

# Ubuntu ships an unrelated program under the name yq, a Python wrapper
# around jq with incompatible syntax. Identify the binary, do not trust PATH.
yq --version 2>&1 | grep -q mikefarah ||
  fail "the yq on PATH is the python jq wrapper, not mikefarah/yq v4."

# Groups the Kubernetes scheme knows about, so Argo can build a strategic
# merge patch and array merge keys apply. Everything else is a custom
# resource: core is the empty group, the rest either end in k8s.io or are
# one of the legacy unsuffixed groups.
BUILTIN_GROUP='^$|(^|\.)k8s\.io$|^(apps|batch|autoscaling|policy|extensions)$'

mapfile -t files < <(find "${ROOT}" -type f \( -name '*.yaml' -o -name '*.yml' \) | sort)
[ "${#files[@]}" -gt 0 ] ||
  fail "no manifests under ${ROOT}, so this check would pass vacuously."

apps_checked=0
respecting=0
violations=""

for f in "${files[@]}"; do
  apps_json=$(yq -o=json -I=0 eval-all '[select(.kind == "Application")]' "${f}")

  count=$(jq 'length' <<<"${apps_json}")
  apps_checked=$((apps_checked + count))

  respecting=$((respecting + $(jq '[.[] | select(
    [(.spec.syncPolicy.syncOptions // [])[] | select(. == "RespectIgnoreDifferences=true")] | length > 0
  )] | length' <<<"${apps_json}")))

  # One tab-separated line per ignoreDifferences path that traverses an
  # array, on an app that has the option on. Tab because a jq path
  # expression can legitimately contain most other punctuation.
  while IFS=$'\t' read -r app group kind expr; do
    [ -n "${app}" ] || continue
    [[ "${group}" =~ ${BUILTIN_GROUP} ]] && continue
    violations+="    ${f}: ${app} ignores '${expr}' on ${group}/${kind}"$'\n'
  done < <(jq -r '
    .[]
    | select([(.spec.syncPolicy.syncOptions // [])[]
              | select(. == "RespectIgnoreDifferences=true")] | length > 0)
    | (.metadata.name // "unnamed") as $app
    | (.spec.ignoreDifferences // [])[]
    | (.group // "") as $g
    | (.kind // "") as $k
    | (.jqPathExpressions // [])[]
    | select(test("\\["))
    | [$app, $g, $k, .] | @tsv
  ' <<<"${apps_json}")
done

[ "${apps_checked}" -gt 0 ] ||
  fail "found no Application manifests under ${ROOT}, so this check would pass vacuously."

log "Scanned ${apps_checked} Application(s) under ${ROOT}; ${respecting} use RespectIgnoreDifferences=true."

if [ -n "${violations}" ]; then
  printf '\033[1;31mFAIL\033[0m %s\n' "an ignoreDifferences path reaches inside an array on a custom resource:"
  printf '%s' "${violations}"
  cat <<'EOF'
    Argo will rebuild that array from the live object and apply it over the
    one in git, so every edit to the resource is discarded without an error.
    Either drop RespectIgnoreDifferences=true from that app, or declare the
    field in the manifest so there is nothing to ignore.
EOF
  exit 1
fi

pass "no Application ignores an in-array field on a custom resource while respecting ignoreDifferences"
