# Deliberately unsigned. This image exists so the negative control in
# `make verify` can prove Kyverno rejects a *resolvable* image that carries
# no signature, rather than one the registry cannot find at all.
#
# FROM scratch keeps it dependency-free: no base image to pull, nothing to
# scan, no CVEs to age. It is never meant to run, only to be refused.
FROM scratch

COPY marker /marker
