# terraform/modules/kind-cluster

Disposable, reproducible kind cluster as a Terraform module — with an optional local OCI registry wired into containerd.

Why Terraform for a local cluster instead of `kind create cluster`? Same reason as everywhere else: version-pinned, reviewable, composable with the rest of your IaC, and destroyable with confidence. It also means CI and laptops build the *same* cluster. See [ADR-0001](../../../../adr/0001-kind-over-cloud-for-reference-implementation.md) for why kind at all.

## Usage

```hcl
module "cluster" {
  source = "github.com/yodim/k8s-secure-supply-chain//components/terraform/modules/kind-cluster"

  cluster_name       = "supply-chain"
  kubernetes_version = "v1.30.0"   # pin deliberately
  worker_count       = 1
}

output "registry" {
  value = module.cluster.registry_host  # push images here: localhost:5001
}
```

A ready-to-run example lives in [`examples/basic`](examples/basic/) — it's what `make up` at repo root applies.

## Inputs

| Name | Default | Description |
|---|---|---|
| `cluster_name` | `supply-chain` | Cluster + kubeconfig context name |
| `kubernetes_version` | `v1.30.0` | kindest/node tag (pinned, never `latest`) |
| `worker_count` | `1` | Worker nodes; 0 works |
| `enable_local_registry` | `true` | Local `registry:2` on the kind network |
| `registry_port` | `5001` | Host port for the registry |

## Outputs

`cluster_name`, `kubeconfig_path`, `context_name`, `registry_host` (push endpoint), `registry_internal` (pull endpoint from inside the cluster).

## How the registry gets wired (the non-obvious part)

Docker's `kind` network doesn't exist until kind creates its first cluster, so the registry **cannot** declare `networks_advanced { name = "kind" }` — that fails on a clean machine with `network kind not found`. The module works around it in three ordered steps:

1. `docker_container.registry` starts detached.
2. `kind_cluster.this` is created (`depends_on` the registry, so containerd's mirror config points at something already listening) — kind creates the `kind` network here.
3. `terraform_data.connect_registry` attaches the registry to that network, guarded so re-running `apply` doesn't error on an already-attached container.

If you refactor this module, keep that order. It looks redundant until you try it on a machine that has never run kind.

## Notes & limits

- The registry is HTTP and bound to `127.0.0.1` — it's a dev/CI convenience, not a production pattern.
- Steps 2 and 3 shell out via `local-exec`, so `docker` and `kubectl` must be on `PATH`. Pure-HCL alternatives exist but need the network to pre-exist, which is the problem being solved.
- The kubeconfig is written to `~/.kube/kind-<name>.yaml`, not merged into your default config, to keep teardown clean.
- Port 8080→30080 is pre-mapped for NodePort ingress in demos; drop the `extra_port_mappings` block if you don't need it.
