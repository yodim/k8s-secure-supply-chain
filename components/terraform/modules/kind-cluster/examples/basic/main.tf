module "cluster" {
  source = "../.."

  cluster_name       = "supply-chain"
  kubernetes_version = "v1.30.0"
  worker_count       = 1
}

output "context_name" {
  value = module.cluster.context_name
}

output "kubeconfig_path" {
  value = module.cluster.kubeconfig_path
}

output "registry_host" {
  value = module.cluster.registry_host
}
