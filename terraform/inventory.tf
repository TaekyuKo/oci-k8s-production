# Ansible 인벤토리 자동 생성
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    master_ips  = oci_core_instance.k8s_master[*].public_ip
    worker_ips  = oci_core_public_ip.worker_ip[*].ip_address
  })
  filename = "${path.module}/../ansible/inventory/hosts.ini"
}
