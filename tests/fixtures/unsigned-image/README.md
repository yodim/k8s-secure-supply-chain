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

This fixture closes that gap. It is a real image, it resolves, it pulls, it matches the policies' `imageReferences` pattern, and it carries no signature and no attestation. When admission refuses it, the refusal is attributable to signature verification and nothing else.

`scripts/verify.sh` asserts on the verdict, not the policy name. Matching on `require-signed-images` alone is not enough, because that policy reports a failure whenever it cannot reach a verdict at all, and those rejections name the same policy. The script requires the message to contain **`no signatures found`**, which is Cosign saying it read the image and there was nothing to verify. It fails with a distinct message, and a distinct remedy, for each way of not knowing:

| Rejection contains | Means | What it is not |
|---|---|---|
| `MANIFEST_UNKNOWN`, `image tag not found`, `name unknown` | the image could not be **resolved** | publish the fixture |
| `UNAUTHORIZED`, `DENIED`, `401`, `403`, `failed to fetch` | the image could not be **read** | fix `ghcr-creds` and the token's `read:packages` |
| `require-signed-images` but not `no signatures found` | refused for some other reason, e.g. an identity mismatch | not evidence this image is unsigned |

## Publishing it

Built and pushed by `.github/workflows/publish-unsigned-fixture.yml`, which deliberately skips every signing step. Run it once per repo or fork:

```bash
gh workflow run publish-unsigned-fixture.yml
```

The workflow also runs automatically when anything in this directory changes. Until it has run at least once, `make verify` will tell you the fixture is missing rather than passing for the wrong reason.

## It is also the build gate's positive control

The `build-gate` job in `ci.yml` scans this image and requires the Trivy gate to **pass** it. "The gate rejected a vulnerable image" only means something next to "the gate admits a clean one", otherwise a permanently broken scanner would satisfy the test.

`FROM scratch` with a single text file is the strongest clean image available: it contains no packages, so it cannot acquire a vulnerability no matter how much time passes. **Adding anything to it breaks that job.** Keep it empty.

## Why this one is published and the vulnerable fixture is not

[`tests/fixtures/vulnerable-image`](../vulnerable-image/) is the matching fixture for the build gate, and it never leaves the runner. The asymmetry is not an inconsistency:

- Admission can only refuse an image it can **resolve**, so this fixture has to exist in a registry, or the test degrades into the 404 problem described above.
- Trivy scans a **local** image, so the vulnerable fixture needs no registry. Publishing it would contradict the rule it exists to verify, that an image failing the scan never reaches one.

## Is publishing an unsigned image a risk?

It is inert. `FROM scratch` with a single text file: no shell, no libraries, no entrypoint that could execute. The cluster this repo builds refuses to run it by design, which is the whole point. Its only purpose is to be rejected.
