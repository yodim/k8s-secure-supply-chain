# Deliberately vulnerable. This image exists so the Trivy gate in
# secure-build.yml can be observed failing a build, rather than only ever
# being observed passing against a clean one.
#
# Built with `load: true` and never pushed. Publishing it would break the
# very rule it exists to test: an image that fails the scan does not reach a
# registry. The unsigned fixture next door has to be published, because
# admission can only refuse what it can resolve. Trivy scans a local image,
# so this one needs no registry at all.
#
# Pinned by digest to a frozen point release, deliberately old. Two things
# must stay true or this silently stops being a test:
#
#   1. The findings must have fix versions. The gate runs with
#      ignore-unfixed and is blind to everything else.
#   2. The base must not be bumped, by a human or a bot. A current base has
#      no fixable CRITICAL or HIGH findings and the gate stops firing.
#
# Chosen over a plain debian-slim because it carries two independent
# advisory sources, Debian bullseye packages and Python packages from PyPI
# data. One source going quiet does not disarm the fixture.
#
# Measured 2026-09-20: 133 findings, all with fixes, 26 CRITICAL and 107
# HIGH. README.md here has the runbook for when that stops being true.
# renovate: ignore
FROM python:3.9.7-slim-bullseye@sha256:aef632387d994b410de020dfd08fb1d9b648fc8a5a44f332f7ee326c8e170dba

LABEL org.opencontainers.image.title="vulnerable-fixture"
LABEL org.opencontainers.image.description="Deliberately vulnerable CI test fixture. Never deploy this."

COPY marker /marker
