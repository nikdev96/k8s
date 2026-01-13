variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "upheld-rookery-471109-b0"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "k8s-ha-network"
}

variable "subnet_cidr" {
  description = "Subnet CIDR range"
  type        = string
  default     = "10.0.0.0/24"
}

variable "master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "Machine type for all nodes"
  type        = string
  default     = "e2-medium"
}

variable "image_family" {
  description = "OS image family"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "image_project" {
  description = "Project containing the OS image"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "service_account_email" {
  description = "Service account email for instances"
  type        = string
  default     = "serviceforbot@upheld-rookery-471109-b0.iam.gserviceaccount.com"
}

variable "vip_address" {
  description = "Virtual IP address for HA"
  type        = string
  default     = "10.0.0.100"
}

variable "ssh_user" {
  description = "SSH user for instances"
  type        = string
  default     = "ubuntu"
}
