# Deliberately unsigned. This image exists so the negative control in
# `make verify` can prove Kyverno rejects a *resolvable* image that carries
# no signature, rather than one the registry cannot find at all.
#
# FROM scratch keeps it dependency-free: no base image to pull, nothing to
# scan, no CVEs to age. It is never meant to run, only to be refused.
#
# That second property gave it a second job: the build-gate job in ci.yml
# scans this image as its positive control, because an image containing
# nothing can never acquire a vulnerability. Adding any package here would
# break that job. Keep it FROM scratch.
FROM scratch

COPY marker /marker
