# disallow-latest-tag

Rejects Pods running `:latest` or untagged images.

Mutable tags break the two things a supply chain exists to provide: knowing what ran (audit) and being able to run it again (rollback). In this platform the [require-signed-images](../require-signed-images/) policy already rewrites tags to digests for signed images — this policy catches everything else, including images outside the signing scope.

## Reuse

Standalone — no dependency on signing or Sigstore. Applies cluster-wide by default; add a `namespaces:` filter under `match` to scope it. Checks `containers`; extend the `foreach` list to `initContainers[]` and `ephemeralContainers[]` if you use them (the platform composition does).

## Test

```bash
kyverno test test/
```
