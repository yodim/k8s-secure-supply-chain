# require-resource-limits

Rejects containers without CPU and memory limits in workload namespaces.

Not strictly a supply chain control — it's here because a "secure platform" that lets one deployment starve the admission controller isn't one. Resource exhaustion is the cheapest availability attack there is.

## Reuse

Standalone. Scoped to the `apps` namespace by default — adjust `namespaces:` under `match`.

Covers `containers` and `initContainers`, the latter marked optional with `=()` so Pods without them are unaffected. An init container runs before the rest of the Pod and can exhaust a node just as easily, so leaving it out would make the rule avoidable.

`ephemeralContainers` is deliberately **not** covered: Kubernetes forbids setting `resources` on them, so requiring limits there would reject every `kubectl debug` session without making anything safer. If your org standardizes on LimitRange defaults instead of hard enforcement, prefer that and run this policy in `Audit` as a reporting layer.

Note: enforcing CPU *limits* (vs only requests) is debated — CPU throttling has real latency costs. This platform enforces both for predictability; if you disagree, drop the `cpu` line and keep memory, which is the non-negotiable one (OOM kills don't throttle, they terminate).

## Test

```bash
kyverno test test/
```
