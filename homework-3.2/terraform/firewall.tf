# Allow SSH from anywhere
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.k8s_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s-node"]
}

# Allow all internal traffic between nodes
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.k8s_network.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["k8s-node"]
}

# Allow Kubernetes API access from anywhere
resource "google_compute_firewall" "allow_k8s_api" {
  name    = "${var.network_name}-allow-k8s-api"
  network = google_compute_network.k8s_network.name

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s-master"]
}

# Allow NodePort services from anywhere
resource "google_compute_firewall" "allow_nodeport" {
  name    = "${var.network_name}-allow-nodeport"
  network = google_compute_network.k8s_network.name

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s-node"]
}

# VRRP for keepalived (IP protocol 112)
resource "google_compute_firewall" "allow_vrrp" {
  name    = "${var.network_name}-allow-vrrp"
  network = google_compute_network.k8s_network.name

  allow {
    protocol = "112"
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["k8s-master"]
}
