[k8s_master]
%{ for idx, ip in master_ips ~}
k8s-master ansible_host=${ip} ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{ endfor ~}

[k8s_workers]
%{ for idx, ip in worker_ips ~}
k8s-worker ansible_host=${ip} ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{ endfor ~}

[k8s_all:children]
k8s_master
k8s_workers

[k8s_all:vars]
ansible_python_interpreter=/usr/bin/python3
