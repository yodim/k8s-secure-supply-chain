locals {
  registry_name = "${var.cluster_name}-registry"
  # Inside the cluster, containerd reaches the registry by container name on the kind network.
  registry_internal = "${local.registry_name}:5000"
}

resource "docker_image" "registry" {
  count = var.enable_local_registry ? 1 : 0

  name         = "registry:2"
  keep_locally = true
}

# NOTE ON ORDERING (this is load-bearing, don't "simplify" it):
# The registry must sit on Docker's 'kind' network so containerd inside the
# nodes can resolve it by name. But that network does not exist until kind
# creates the first cluster. So the registry is created detached here, the
# cluster is created next, and terraform_data.connect_registry attaches the
# registry afterwards. Declaring networks_advanced { name = "kind" } on this
# resource fails on a clean machine with "network kind not found".
resource "docker_container" "registry" {
  count = var.enable_local_registry ? 1 : 0

  name    = local.registry_name
  image   = docker_image.registry[0].image_id
  restart = "always"

  ports {
    internal = 5000
    external = var.registry_port
    ip       = "127.0.0.1"
  }
}

resource "kind_cluster" "this" {
  name            = var.cluster_name
  node_image      = "kindest/node:${var.kubernetes_version}"
  wait_for_ready  = true
  kubeconfig_path = pathexpand("~/.kube/kind-${var.cluster_name}.yaml")

  # Registry first: it must be running before nodes start, so containerd's
  # mirror config points at something that answers.
  depends_on = [docker_container.registry]

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    containerd_config_patches = var.enable_local_registry ? [
      <<-TOML
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${var.registry_port}"]
          endpoint = ["http://${local.registry_internal}"]
      TOML
    ] : []

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        <<-YAML
          kind: InitConfiguration
          nodeRegistration:
            kubeletExtraArgs:
              node-labels: "ingress-ready=true"
        YAML
      ]

      extra_port_mappings {
        container_port = 30080
        host_port      = 8080
        protocol       = "TCP"
      }
    }

    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"
      }
    }
  }
}

# Attach the registry to kind's network now that kind has created it.
# `docker network connect` is not idempotent (it errors if the container is
# already attached), hence the guard — this must survive re-runs of apply.
resource "terraform_data" "connect_registry" {
  count = var.enable_local_registry ? 1 : 0

  triggers_replace = [
    docker_container.registry[0].id,
    kind_cluster.this.id,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      docker network inspect kind --format '{{range .Containers}}{{.Name}} {{end}}' \
        | grep -qw "${local.registry_name}" \
        || docker network connect kind "${local.registry_name}"
    EOT
  }
}

# Advertise the registry to tooling per KEP-1755, so `kind`-aware tools and
# humans can discover it without reading this file.
resource "terraform_data" "registry_hosting_configmap" {
  count = var.enable_local_registry ? 1 : 0

  triggers_replace = [kind_cluster.this.id]

  provisioner "local-exec" {
    # kind writes a dedicated kubeconfig, not ~/.kube/config, so the context
    # is invisible to kubectl unless we point KUBECONFIG at it explicitly.
    environment = {
      KUBECONFIG = kind_cluster.this.kubeconfig_path
    }

    command = <<-EOT
      kubectl --context kind-${var.cluster_name} apply -f - <<'MANIFEST'
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: local-registry-hosting
        namespace: kube-public
      data:
        localRegistryHosting.v1: |
          host: "localhost:${var.registry_port}"
          help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
      MANIFEST
    EOT
  }

  depends_on = [terraform_data.connect_registry]
}
