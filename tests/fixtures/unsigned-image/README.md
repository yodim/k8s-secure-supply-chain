# Unsigned test fixture

A container image published **without a signature, on purpose**, so the negative control in `make verify` tests what it claims to test.

## Why this exists

The negative control asks admission to run an image that should be refused. Without a fixture, the obvious shortcut is to point it at an image name that does not exist:

```bash
kubectl run test --image=ghcr.io/org/does-not-exist:1.0.0
```

Kyverno does reject that, so the test passes. But read the rejection:

```
image tag not found: MANIFEST_UNKNOWN: manifest unknown
```

It failed because the registry had nothing to return, not because the image was unsigned. The same result would appear with every verification rule deleted, which makes the test worthless as evidence: it proves the registry can 404, not that the cluster enforces signatures.

This fixture closes that gap. It is a real image, it resolves, it pulls, it matches the policies' `imageReferences` pattern, and it carries no signature and no attestation. When admission refuses it, the refusal is attributable to signature verification and nothing else. `scripts/verify.sh` asserts on the reason, and fails loudly if it sees a resolution error instead.

## Publishing it

Built and pushed by `.github/workflows/publish-unsigned-fixture.yml`, which deliberately skips every signing step. Run it once per repo or fork:

```bash
gh workflow run publish-unsigned-fixture.yml
```

The workflow also runs automatically when anything in this directory changes. Until it has run at least once, `make verify` will tell you the fixture is missing rather than passing for the wrong reason.

## Is publishing an unsigned image a risk?

It is inert. `FROM scratch` with a single text file: no shell, no libraries, no entrypoint that could execute. The cluster this repo builds refuses to run it by design, which is the whole point. Its only purpose is to be rejected.
