output "master_external_ips" {
  description = "External IP addresses of master nodes"
  value = {
    for idx, instance in google_compute_instance.k8s_master :
      instance.name => instance.network_interface[0].access_config[0].nat_ip
  }
}

output "master_internal_ips" {
  description = "Internal IP addresses of master nodes"
  value = {
    for idx, instance in google_compute_instance.k8s_master :
      instance.name => instance.network_interface[0].network_ip
  }
}

output "worker_external_ips" {
  description = "External IP addresses of worker nodes"
  value = {
    for idx, instance in google_compute_instance.k8s_worker :
      instance.name => instance.network_interface[0].access_config[0].nat_ip
  }
}

output "worker_internal_ips" {
  description = "Internal IP addresses of worker nodes"
  value = {
    for idx, instance in google_compute_instance.k8s_worker :
      instance.name => instance.network_interface[0].network_ip
  }
}

output "vip_address" {
  description = "Virtual IP address for HA"
  value       = var.vip_address
}

output "all_nodes_info" {
  description = "All nodes information"
  value = {
    masters = [
      for instance in google_compute_instance.k8s_master : {
        name        = instance.name
        internal_ip = instance.network_interface[0].network_ip
        external_ip = instance.network_interface[0].access_config[0].nat_ip
      }
    ]
    workers = [
      for instance in google_compute_instance.k8s_worker : {
        name        = instance.name
        internal_ip = instance.network_interface[0].network_ip
        external_ip = instance.network_interface[0].access_config[0].nat_ip
      }
    ]
  }
}

output "ssh_commands" {
  description = "SSH commands to connect to nodes"
  value = {
    masters = [
      for instance in google_compute_instance.k8s_master :
      "ssh ${var.ssh_user}@${instance.network_interface[0].access_config[0].nat_ip}"
    ]
    workers = [
      for instance in google_compute_instance.k8s_worker :
      "ssh ${var.ssh_user}@${instance.network_interface[0].access_config[0].nat_ip}"
    ]
  }
}
