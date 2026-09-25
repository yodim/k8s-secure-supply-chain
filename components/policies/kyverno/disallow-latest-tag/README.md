# disallow-latest-tag

Rejects Pods running `:latest` or untagged images.

Mutable tags break the two things a supply chain exists to provide: knowing what ran (audit) and being able to run it again (rollback). In this platform the [require-signed-images](../require-signed-images/) policy already rewrites tags to digests for signed images — this policy catches everything else, including images outside the signing scope.

## Reuse

Standalone — no dependency on signing or Sigstore. Applies cluster-wide by default; add a `namespaces:` filter under `match` to scope it.

Checks `containers`, `initContainers` and `ephemeralContainers`. All three are needed: an init container runs before anything else in the Pod, and an ephemeral container is exactly what `kubectl debug` attaches to a running one, so a rule covering only `containers` is avoidable by anyone who knows either exists.

## What counts as untagged

Anything with no tag and no digest **on the image name**, which is the part after the last slash. Testing the whole reference for a colon is the obvious implementation and it is wrong: `localhost:5001/app` contains a colon, but that colon is the registry port, and the image has no tag at all. The runtime resolves it to `:latest`, which is precisely what this policy exists to stop. There is a test for it, alongside `localhost:5001/app:1.0`, which must still pass.

## Test

```bash
kyverno test test/
```
