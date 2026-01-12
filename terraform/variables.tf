variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "netology-k8s-cluster"
}

variable "machine_type" {
  description = "Node machine type"
  type        = string
  default     = "e2-small"
}

variable "node_count" {
  description = "Number of nodes"
  type        = number
  default     = 1
}
