output "cluster_name" {
  description = "kind cluster name."
  value       = kind_cluster.this.name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig."
  value       = kind_cluster.this.kubeconfig_path
}

output "context_name" {
  description = "kubectl context name."
  value       = "kind-${kind_cluster.this.name}"
}

output "registry_host" {
  description = "Local registry endpoint for pushing images (empty if disabled)."
  value       = var.enable_local_registry ? "localhost:${var.registry_port}" : ""
}

output "registry_internal" {
  description = "Registry endpoint as seen from inside the cluster (empty if disabled)."
  value       = var.enable_local_registry ? local.registry_internal : ""
}
