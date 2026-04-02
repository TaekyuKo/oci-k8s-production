# Master Nodes
output "master_public_ips" {
  value       = oci_core_instance.k8s_master[*].public_ip
  description = "Ephemeral public IPs of master nodes"
}

output "master_private_ips" {
  value       = oci_core_instance.k8s_master[*].private_ip
  description = "Private IPs of master nodes"
}

# Worker Nodes
output "worker_public_ips" {
  value       = oci_core_public_ip.worker_ip[*].ip_address
  description = "Reserved public IPs of worker nodes"
}

output "worker_private_ips" {
  value       = oci_core_instance.k8s_worker[*].private_ip
  description = "Private IPs of worker nodes"
}

# SSH Connection Info
output "ssh_connection_commands" {
  value = <<-EOT
    # Master nodes (Ephemeral IPs)
    %{for idx, ip in oci_core_instance.k8s_master[*].public_ip~}
    ssh ubuntu@${ip}  # master-${idx + 1}
    %{endfor~}
    
    # Worker nodes (Reserved IPs)
    %{for idx, ip in oci_core_public_ip.worker_ip[*].ip_address~}
    ssh ubuntu@${ip}  # worker-${idx + 1}
    %{endfor~}
  EOT
  description = "SSH connection commands for all nodes"
}

# Primary Worker IP (for app traffic)
output "primary_worker_ip" {
  value       = oci_core_public_ip.worker_ip[0].ip_address
  description = "Primary worker node public IP for application traffic"
}
