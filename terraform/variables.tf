# OCI 인증 정보
variable "tenancy_ocid" {
  type        = string
  description = "OCI Tenancy OCID"
}

variable "user_ocid" {
  type        = string
  description = "OCI User OCID"
}

variable "fingerprint" {
  type        = string
  description = "API Key Fingerprint"
}

variable "private_key_path" {
  type        = string
  description = "Path to OCI API private key"
}

variable "region" {
  type        = string
  description = "OCI Region"
}

# 리소스
variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for instance access"
  sensitive   = true
}

# 클러스터 설정
variable "cluster_name" {
  type        = string
  default     = "k8s-prod"
  description = "Kubernetes cluster name"
}

variable "master_count" {
  type        = number
  default     = 1
  description = "Number of master nodes (OCI Free Tier: 1 only)"
  
  validation {
    condition     = var.master_count == 1
    error_message = "OCI Free Tier supports only 1 master node (1 Reserved IP limit)."
  }
}

variable "worker_count" {
  type        = number
  default     = 1
  description = "Number of worker nodes (OCI Free Tier: adjust based on OCPU/Memory limits)"
  
  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 3
    error_message = "Worker count must be between 1 and 3 (Free Tier OCPU limit: 4 total)."
  }
}

# 인스턴스 사양
variable "instance_shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  type    = number
  default = 2
  
  validation {
    condition     = var.instance_ocpus * (var.master_count + var.worker_count) <= 4
    error_message = "Total OCPU count exceeds Free Tier limit (4 OCPU). Reduce instance_ocpus or node count."
  }
}

variable "instance_memory" {
  type    = number
  default = 12
  
  validation {
    condition     = var.instance_memory * (var.master_count + var.worker_count) <= 24
    error_message = "Total memory exceeds Free Tier limit (24GB). Reduce instance_memory or node count."
  }
}

variable "boot_volume_size" {
  type    = number
  default = 50
}

variable "block_volume_size" {
  type    = number
  default = 50
}
