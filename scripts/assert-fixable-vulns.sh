#!/usr/bin/env bash
# A scanner exiting non-zero is not evidence on its own. Trivy also exits
# non-zero when it cannot resolve the image, cannot reach the Docker daemon,
# or cannot download its database. Any of those would satisfy a naive "the
# gate failed, therefore the gate works" test while proving nothing, which
# is the same bug as an unsigned-image test that only proves a registry can
# return a 404.
#
# This asserts the fixture actually contains what the gate claims to stop:
# findings at the gated severities that have a fix available, because the
# gate runs with ignore-unfixed and is blind to everything else.
set -euo pipefail

REPORT="${1:?usage: assert-fixable-vulns.sh <trivy-json> <severities>}"
WANT="${2:?usage: assert-fixable-vulns.sh <trivy-json> <severities>}"
RUNBOOK="tests/fixtures/vulnerable-image/README.md"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*"; exit 1; }
warn() {
  printf '\033[1;33mWARN\033[0m %s\n' "$*"
  [ -z "${GITHUB_ACTIONS:-}" ] || printf '::warning::%s\n' "$*"
}

[ -s "${REPORT}" ] ||
  fail "${REPORT} is missing or empty: the scan produced no report, so it did not run."

total=$(jq '[.Results[]?.Vulnerabilities[]?] | length' "${REPORT}")
fixable=$(jq '[.Results[]?.Vulnerabilities[]? | select((.FixedVersion // "") != "")] | length' "${REPORT}")

log "Fixture at ${WANT}: ${total} findings, ${fixable} with a fix available"
jq -r '.Results[]? | select((.Vulnerabilities | length) > 0)
       | "    \(.Class)  \(.Target)  \(.Vulnerabilities | length)"' "${REPORT}"

[ "${total}" -gt 0 ] ||
  fail "the fixture reports no ${WANT} vulnerabilities at all.
     Either the base image was bumped, or it has aged out of the vulnerability database.
     Runbook: ${RUNBOOK}"

[ "${fixable}" -gt 0 ] ||
  fail "every ${WANT} finding in the fixture is unfixed.
     The gate runs with ignore-unfixed, so it will suppress all of them and pass an image it
     should stop. Re-pin the fixture. Runbook: ${RUNBOOK}"

# Per-severity coverage is a warning rather than a failure: narrowing the
# gate to a single severity is a legitimate change. But it is the first sign
# the fixture is ageing out.
IFS=',' read -r -a wanted <<< "${WANT}"
for sev in "${wanted[@]}"; do
  n=$(jq --arg s "${sev}" '[.Results[]?.Vulnerabilities[]?
       | select(.Severity == $s and (.FixedVersion // "") != "")] | length' "${REPORT}")
  [ "${n}" -gt 0 ] ||
    warn "no fixable ${sev} findings. Narrow the gate to ${sev} alone and this test stops working."
done

[ "${fixable}" -ge 5 ] ||
  warn "only ${fixable} fixable findings left. The fixture is thinning out; re-pin it soon."

pass "the fixture carries findings of exactly the kind the gate exists to stop"
