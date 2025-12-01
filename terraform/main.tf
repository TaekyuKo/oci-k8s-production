# =================================================================
# 데이터 소스 (Data Sources)
# =================================================================
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "ubuntu_image" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# =================================================================
# 네트워크 (Networking)
# =================================================================

# VCN & Internet Gateway 
resource "oci_core_vcn" "k8s_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "${var.cluster_name}-vcn"
  dns_label      = "k8svcn"
}

resource "oci_core_internet_gateway" "k8s_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "${var.cluster_name}-igw"
}

# Public Subnet
resource "oci_core_subnet" "public_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.k8s_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "${var.cluster_name}-public-subnet"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.public_rt.id
  security_list_ids = [oci_core_security_list.k8s_sl.id]
}

# Route Table 
resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "${var.cluster_name}-public-rt"
  
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.k8s_igw.id
  }
}

# =================================================================
# 보안 (Security)
# =================================================================

resource "oci_core_security_list" "k8s_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "${var.cluster_name}-cluster-sl"
  
  # 아웃바운드 트래픽 전체 허용
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound traffic."
  }
  
  # VCN 내부 통신 (Kubernetes Pod 간 통신 필수)
  ingress_security_rules {
    protocol    = "all"
    source      = "10.0.0.0/16"
    description = "Allow all internal VCN traffic for Kubernetes."
  }
  
  # SSH 접근
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options { 
      min = 22 
      max = 22 
    }
    description = "Allow SSH access from anywhere (key-based authentication)."
  }
  
  # Kubernetes API Server
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options { 
      min = 6443 
      max = 6443 
    }
    description = "Allow Kubernetes API access from anywhere (requires proper authentication)."
  }
  
  # ICMP (ping)
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "Allow ICMP for ping."
  }
  
  # HTTP
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options { 
      min = 80 
      max = 80 
    }
    description = "Allow HTTP traffic."
  }
  
  # HTTPS 
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options { 
      min = 443 
      max = 443 
    }
    description = "Allow HTTPS traffic."
  }
  
  # NodePort 서비스 
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options { 
      min = 30000 
      max = 32767 
    }
    description = "Allow Kubernetes NodePort services."
  }
}

# =================================================================
# 컴퓨트 (Compute Instances)
# =================================================================

# --- Master Nodes ---
resource "oci_core_instance" "k8s_master" {
  count               = var.master_count
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "k8s-master"
  shape               = var.instance_shape
  
  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory
  }
  
  create_vnic_details {
    subnet_id                 = oci_core_subnet.public_subnet.id
    assign_public_ip          = false
    assign_private_dns_record = true
    skip_source_dest_check    = true
  }
  
  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_image.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size
  }
  
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
  
  timeouts {
    create = "30m"
    delete = "30m"
  }
}

# Master Node Reserved IP (첫 번째만)
resource "oci_core_public_ip" "master_ip" {
  count          = var.master_count
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "k8s-master-ip"
  private_ip_id  = data.oci_core_private_ips.master_private_ip[count.index].id

  depends_on = [oci_core_instance.k8s_master]
}

data "oci_core_private_ips" "master_private_ip" {
  count   = var.master_count
  vnic_id = data.oci_core_vnic_attachments.master_vnic[count.index].vnic_attachments[0].vnic_id
}

data "oci_core_vnic_attachments" "master_vnic" {
  count          = var.master_count
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.k8s_master[count.index].id
}

# Master Block Volumes
resource "oci_core_volume" "master_bv" {
  count               = var.master_count
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "k8s-master-bv"
  size_in_gbs         = var.block_volume_size
}

resource "oci_core_volume_attachment" "master_bv_attachment" {
  count           = var.master_count
  attachment_type = "iscsi"
  instance_id     = oci_core_instance.k8s_master[count.index].id
  volume_id       = oci_core_volume.master_bv[count.index].id
  display_name    = "k8s-master-bv-attachment"
  device          = "/dev/oracleoci/oraclevdb"
}

# --- Worker Nodes ---
resource "oci_core_instance" "k8s_worker" {
  count               = var.worker_count
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "k8s-worker"
  shape               = var.instance_shape
  
  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory
  }
  
  create_vnic_details {
    subnet_id                 = oci_core_subnet.public_subnet.id
    assign_public_ip          = true
    assign_private_dns_record = true
    skip_source_dest_check    = true
  }
  
  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_image.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size
  }
  
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
  
  timeouts {
    create = "30m"
    delete = "30m"
  }
}

# Worker Block Volumes
resource "oci_core_volume" "worker_bv" {
  count               = var.worker_count
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "k8s-worker-bv"
  size_in_gbs         = var.block_volume_size
}

resource "oci_core_volume_attachment" "worker_bv_attachment" {
  count           = var.worker_count
  attachment_type = "iscsi"
  instance_id     = oci_core_instance.k8s_worker[count.index].id
  volume_id       = oci_core_volume.worker_bv[count.index].id
  display_name    = "k8s-worker-bv-attachment"
  device          = "/dev/oracleoci/oraclevd${chr(99 + count.index)}"
}
