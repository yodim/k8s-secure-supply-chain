variable "cluster_name" {
  description = "Name of the kind cluster (also used for kubeconfig context: kind-<name>)."
  type        = string
  default     = "supply-chain"
}

variable "kubernetes_version" {
  description = "kindest/node image tag pinning the Kubernetes version. Pin deliberately; 'latest' is not reproducible."
  type        = string
  default     = "v1.30.0"
}

variable "worker_count" {
  description = "Number of worker nodes. 0 is fine for this platform; the control plane schedules workloads."
  type        = number
  default     = 1
}

variable "enable_local_registry" {
  description = "Run a local OCI registry (registry:2) wired into containerd, reachable at localhost:<port>."
  type        = bool
  default     = true
}

variable "registry_port" {
  description = "Host port for the local registry."
  type        = number
  default     = 5001
}
