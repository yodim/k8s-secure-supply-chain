#!/usr/bin/env bash
# Reads the Trivy gate out of secure-build.yml so the negative control in
# ci.yml exercises the real configuration instead of a copy of it.
#
# A copy is exactly the failure this guards against: someone relaxes the
# gate, the test keeps exercising the old values, and CI stays green while
# nothing is enforced. Reading the live values means a relaxed gate relaxes
# the test too, the fixture stops being rejected, and the job goes red.
#
# It also asserts the structure the gate depends on, including the one thing
# that was previously only a promise in prose: the scan runs before the push.
set -euo pipefail

WORKFLOW="${WORKFLOW:-.github/workflows/secure-build.yml}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*"; exit 1; }

[ -f "${WORKFLOW}" ] ||
  fail "${WORKFLOW} not found. If the reusable workflow moved, update WORKFLOW here and in ci.yml."

command -v yq >/dev/null 2>&1 ||
  fail "yq (mikefarah v4) is required: https://github.com/mikefarah/yq#install"

# Ubuntu ships an unrelated program under the same name, a Python wrapper
# around jq with incompatible syntax. Identify the binary, do not trust PATH.
yq --version 2>&1 | grep -q mikefarah ||
  fail "the yq on PATH is the python jq wrapper, not mikefarah/yq v4."

# Hyphenated keys need bracket syntax; '-' is subtraction in a yq expression.
TRIVY='.jobs.build.steps | map(select((.uses // "") | test("^aquasecurity/trivy-action@")))'

gate_count=$(yq "${TRIVY} | length" "${WORKFLOW}")
[ "${gate_count}" = "1" ] ||
  fail "expected exactly one trivy-action step in jobs.build, found ${gate_count}.
     Either the gate was removed, or there are two and this check cannot tell which one gates."

gate_uses=$(yq "${TRIVY} | .[0].uses" "${WORKFLOW}")
gate_ref=$(yq "${TRIVY} | .[0].with[\"image-ref\"]" "${WORKFLOW}")
gate_exit=$(yq "${TRIVY} | .[0].with[\"exit-code\"]" "${WORKFLOW}")
gate_unfixed=$(yq "${TRIVY} | .[0].with[\"ignore-unfixed\"]" "${WORKFLOW}")
gate_sev=$(yq "${TRIVY} | .[0].with.severity" "${WORKFLOW}")

gate_idx=$(yq '.jobs.build.steps | to_entries
  | map(select((.value.uses // "") | test("^aquasecurity/trivy-action@"))) | .[0].key' "${WORKFLOW}")
push_idx=$(yq '.jobs.build.steps | to_entries
  | map(select(.value.with.push == true)) | .[0].key' "${WORKFLOW}")
load_ref=$(yq '.jobs.build.steps | map(select(.with.load == true)) | .[0].with.tags' "${WORKFLOW}")

# go-yaml v3 treats 'on' as a plain string key, but tolerate a parser that
# resolves it to the boolean true.
sev_default=$(yq '(.on // .true).workflow_call.inputs["fail-on-severity"].default' "${WORKFLOW}")

case "${gate_uses}" in
  *@v[0-9]*) : ;;
  *@[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) : ;;
  *) fail "trivy-action is not pinned to a release tag or sha: ${gate_uses}" ;;
esac

[ "${push_idx}" != "null" ] ||
  fail "no step with 'push: true' in jobs.build, so scan-before-push cannot be checked."

# The central claim of this pipeline. The component README asserted it in
# prose; nothing enforced it until now.
[ "${gate_idx}" -lt "${push_idx}" ] ||
  fail "Trivy runs after the push (step ${gate_idx} vs ${push_idx}).
     Scan before push is the promise: an image that fails the gate must never reach the registry."

[ "${gate_ref}" = "${load_ref}" ] ||
  fail "the gate scans '${gate_ref}' but the build produced '${load_ref}'.
     The scan is not looking at the image that gets pushed."

if [ "${gate_exit}" = "0" ] || [ "${gate_exit}" = "null" ]; then
  fail "the gate's exit-code is '${gate_exit}': it reports findings but does not fail the build."
fi

# shellcheck disable=SC2016  # the literal Actions expression is the expected value
[ "${gate_sev}" = '${{ inputs.fail-on-severity }}' ] ||
  fail "severity is no longer wired to the fail-on-severity input (found '${gate_sev}').
     If that was deliberate, update this check deliberately too."

if [ -z "${sev_default}" ] || [ "${sev_default}" = "null" ]; then
  fail "fail-on-severity has no default, so there is nothing for the negative control to test."
fi

log "Gate under test, read from ${WORKFLOW}:"
printf '    action:         %s\n' "${gate_uses}"
printf '    exit-code:      %s\n' "${gate_exit}"
printf '    ignore-unfixed: %s\n' "${gate_unfixed}"
printf '    severity:       %s\n' "${sev_default}"
printf '    runs at step %s, push at step %s\n' "${gate_idx}" "${push_idx}"
pass "the gate is present, pinned, gating, and running before the push"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    printf 'exit-code=%s\n' "${gate_exit}"
    printf 'ignore-unfixed=%s\n' "${gate_unfixed}"
    printf 'severity=%s\n' "${sev_default}"
  } >> "${GITHUB_OUTPUT}"
fi
