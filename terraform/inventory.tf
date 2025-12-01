# Ansible 인벤토리 자동 생성
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    master_ips  = oci_core_public_ip.master_ip[*].ip_address
    worker_ips  = oci_core_instance.k8s_worker[*].public_ip
  })
  filename = "${path.module}/../ansible/inventory/hosts.ini"
}
