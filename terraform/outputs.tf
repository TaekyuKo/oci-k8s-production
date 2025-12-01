# Master Nodes
output "master_public_ips" {
  value       = oci_core_public_ip.master_ip[*].ip_address
  description = "Reserved public IPs of master nodes"
}

output "master_private_ips" {
  value       = oci_core_instance.k8s_master[*].private_ip
  description = "Private IPs of master nodes"
}

# Worker Nodes
output "worker_public_ips" {
  value       = oci_core_instance.k8s_worker[*].public_ip
  description = "Ephemeral public IPs of worker nodes"
}

output "worker_private_ips" {
  value       = oci_core_instance.k8s_worker[*].private_ip
  description = "Private IPs of worker nodes"
}

# SSH Connection Info
output "ssh_connection_commands" {
  value = <<-EOT
    # Master nodes (Reserved IPs)
    %{for idx, ip in oci_core_public_ip.master_ip[*].ip_address~}
    ssh ubuntu@${ip}  # master-${idx + 1}
    %{endfor~}
    
    # Worker nodes (Ephemeral IPs)
    %{for idx, ip in oci_core_instance.k8s_worker[*].public_ip~}
    ssh ubuntu@${ip}  # worker-${idx + 1}
    %{endfor~}
  EOT
  description = "SSH connection commands for all nodes"
}

# Primary Master IP (for kubectl config)
output "primary_master_ip" {
  value       = oci_core_public_ip.master_ip[0].ip_address
  description = "Primary master node public IP for kubectl configuration"
}
