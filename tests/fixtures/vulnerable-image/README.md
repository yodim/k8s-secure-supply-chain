# Vulnerable test fixture

An image built from a **deliberately outdated base**, so the Trivy gate in `secure-build.yml` can be caught doing its job.

## Why this exists

The demo app builds on a Chainguard base that reports zero vulnerabilities. That is the right choice for the demo app and the wrong situation for the gate: every observation of the gate has been it passing. A gate that has never refused anything is indistinguishable from a gate that is switched off.

## Why the obvious version of this test is worthless

The tempting implementation is: build something vulnerable, run Trivy, assert the step failed.

That proves nothing. Trivy exits non-zero for plenty of reasons that have nothing to do with vulnerabilities:

- the image was never loaded into the daemon
- the vulnerability database could not be downloaded
- the registry rate-limited the database pull
- the tag has a typo

Each of those turns the step red, so a test asserting "the step failed" passes while the gate itself may be doing nothing at all. It is the same mistake as the unsigned-image test that was really only proving a registry can return a 404.

So the job runs the scan **twice, identical except for the gate flag**:

1. **Evidence scan**, `exit-code: 0`, JSON output, no `continue-on-error`. This one must succeed. Every infrastructure failure above lands here, loudly, before the gate is exercised.
2. **Assertion** that the report contains findings of the gated severities, each with a real `FixedVersion`. The gate runs `ignore-unfixed`, so anything without a fix is invisible to it and cannot be what trips it.
3. **Gate scan**, the real `exit-code`, expected to fail.

Because steps 1 and 3 differ in exactly one input, the failure in step 3 is attributable to that input. That is what makes it evidence rather than a coincidence.

## Why this base

`python:3.9.7-slim-bullseye`, pinned by its multi-arch index digest.

Two properties matter, and the first one is easy to get wrong:

**Rolling tags do not work.** `debian:11-slim` and `debian:12-slim` each yield exactly **zero** fixable CRITICAL or HIGH findings. They are rebuilt with security patches, and the CVEs that remain are ones Debian has marked won't-fix, which `ignore-unfixed` then filters away entirely. A fixture built on a rolling tag scans clean and proves nothing. Frozen point releases are never rebuilt, so their packages fall behind fixes that have since been published, which is precisely the condition the gate looks for. This gets more reliable with age, not less.

**Two advisory sources beat one.** This image carries Debian bullseye OS packages *and* Python packages that Trivy reads from `dist-info/METADATA`. If Debian's data ever shifts, the PyPI side still fires.

Measured on 2026-09-20 with the production flags:

| | |
|---|---|
| Findings | 133, every one with a fix available |
| Severity | 26 CRITICAL, 107 HIGH |
| Sources | 129 Debian OS packages, 4 Python packages |

The 26 CRITICAL matter as headroom: the fixture keeps working even if the gate is later narrowed to CRITICAL alone.

Rejected alternatives, recorded so nobody re-proposes them:

- `knqyf263/vuln-image:1.2.3`, the Trivy author's demo image. A third-party personal Docker Hub repository is an absurd dependency for a supply chain project, and it is rate-limited.
- `FROM scratch` plus a vulnerable `requirements.txt`. Elegant, and it does not work: `trivy image` does not read lock files, only OS package databases and installed package metadata.

## Why it is never published

The unsigned fixture next door **must** exist in a registry, because admission can only refuse an image it can resolve. This one must **not**, because Trivy scans a local image and pushing a knowingly vulnerable artifact would contradict the rule the fixture exists to verify: an image that fails the scan does not reach a registry.

The CI job enforces this rather than trusting it. It checks `RepoDigests` on the built image, which the daemon only populates after a push or a pull, and fails if it is non-empty. The job also runs without `packages: write` and never logs in to a registry, so the fixture is structurally incapable of leaving the runner.

## Is keeping a vulnerable Dockerfile in the repo a risk?

It is never pushed and never deployed. The base is a public official image that anyone can already pull; this repository adds a digest and a warning label to it. The real risk is somebody copying this Dockerfile into a real project, which is what the comments at the top of it are for.

## When it stops firing

It will eventually, and the failure is loud by design: `scripts/assert-fixable-vulns.sh` fails and points back here. There is also a warning once the fixable count drops below five, which is the signal to act before it breaks.

Reproduce locally with Docker and Trivy:

```bash
docker build -t vulnerable-fixture:local tests/fixtures/vulnerable-image

# The gate itself. Expect exit code 1.
trivy image --scanners vuln --severity CRITICAL,HIGH --ignore-unfixed \
  --exit-code 1 vulnerable-fixture:local

# The evidence. Every finding should carry a FixedVersion, and both
# os-pkgs and lang-pkgs rows should be non-zero.
trivy image --scanners vuln --severity CRITICAL,HIGH --ignore-unfixed \
  --format json -o /tmp/fixture.json vulnerable-fixture:local
jq -r '.Results[] | "\(.Class) \(.Target) \(.Vulnerabilities|length)"' /tmp/fixture.json
```

To re-pin, walk down this list until one produces fixable CRITICAL and HIGH findings from more than one source, preferring older frozen point releases:

1. `python:3.8.12-slim-buster`
2. `node:18.16-slim` (75 fixable as of 2026-09-20, Debian plus npm)
3. `debian:11.6-slim` (61 fixable, Debian only, single source)
4. Any older official point release

Take the **index** digest so the fixture still builds on arm64:

```bash
docker buildx imagetools inspect python:3.8.12-slim-buster | head -3
```

After re-pinning, re-run the meta-check below. A fixture nobody has watched fail is the thing this repository argues against.

## The meta-check

Worth doing once after any change here. Point the fixture at a clean base, for example `cgr.dev/chainguard/python:latest`, push the branch, and confirm the `build-gate` job goes **red** with the message from `assert-fixable-vulns.sh`. Then revert.

Result of the last run, 2026-09-20: confirmed red, with `every CRITICAL,HIGH finding in the fixture is unfixed` and a pointer to this file.

## Do not let a bot bump this

The `FROM` line carries a `# renovate: ignore` marker. A dependency bot updating this digest to something current would leave the fixture clean and the gate untested. If you adopt Dependabot, exclude this directory there too. The findings assertion catches it either way, but it should not get that far.

## Related

`tests/fixtures/unsigned-image/` is the matching fixture for admission control, and it doubles as this job's positive control. It must stay `FROM scratch`.
