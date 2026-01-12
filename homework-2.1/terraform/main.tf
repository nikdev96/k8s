terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  # Удаляем default node pool и создаем отдельно управляемый
  remove_default_node_pool = true
  initial_node_count       = 1

  # Включаем Workload Identity (рекомендуется)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Настройки сети
  network    = "default"
  subnetwork = "default"
}

# Отдельно управляемый Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    # OAuth scopes для доступа к GCP сервисам
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Метаданные и лейблы
    labels = {
      environment = "homework"
      project     = "k8s-storage"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # Autoscaling (опционально)
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  # Управление обновлениями
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
