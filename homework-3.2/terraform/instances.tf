# Master nodes
resource "google_compute_instance" "k8s_master" {
  count        = var.master_count
  name         = "k8s-master-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["k8s-node", "k8s-master"]

  boot_disk {
    initialize_params {
      image = "${var.image_project}/${var.image_family}"
      size  = var.disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.name

    access_config {
      # Ephemeral external IP
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file("~/.ssh/id_rsa.pub")}"
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  # Allow IP forwarding for Kubernetes networking
  can_ip_forward = true

  # Metadata for node identification
  labels = {
    role = "master"
    cluster = "k8s-ha"
  }
}

# Worker nodes
resource "google_compute_instance" "k8s_worker" {
  count        = var.worker_count
  name         = "k8s-worker-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["k8s-node", "k8s-worker"]

  boot_disk {
    initialize_params {
      image = "${var.image_project}/${var.image_family}"
      size  = var.disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.k8s_subnet.name

    access_config {
      # Ephemeral external IP
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file("~/.ssh/id_rsa.pub")}"
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  # Allow IP forwarding for Kubernetes networking
  can_ip_forward = true

  # Metadata for node identification
  labels = {
    role = "worker"
    cluster = "k8s-ha"
  }
}
