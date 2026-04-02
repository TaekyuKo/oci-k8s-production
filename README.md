# OCI Kubernetes Production Cluster

**Terraform + Ansible 기반 프로덕션급 Kubernetes 클러스터 자동화**

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-blue?logo=terraform)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-%3E%3D2.14-red?logo=ansible)](https://www.ansible.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.35-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![OCI](https://img.shields.io/badge/OCI-Free%20Tier-red?logo=oracle)](https://www.oracle.com/cloud/free/)

Oracle Cloud Infrastructure에서 Terraform과 Ansible을 활용한 프로덕션급 Kubernetes 클러스터 완전 자동 구축.

---

## 🎯 특징

- ⚡ **원클릭 배포**: 인프라부터 애드온까지 완전 자동화
- � **분산 스토리지**: Longhorn으로 PVC 동적 프로비저닝
- �📊 **Observability**: Prometheus, Grafana, Loki 기본 탑재
- 🚀 **GitOps Ready**: ArgoCD로 즉시 CD 파이프라인 구축
- 💰 **프리티어**: OCI Free Tier 범위 내 무료 운영

---

## 📦 기술 스택

### **인프라 (Terraform)**
- VCN + Subnet + Security List
- Compute Instances (ARM64 Ampere A1)
- Block Volumes (Longhorn 백엔드 스토리지)
- Reserved Public IP

### **Kubernetes 기본**
- **Runtime**: containerd 1.7.28
- **Kubernetes**: v1.35.2
- **CNI**: Cilium v1.19.1 (eBPF, VXLAN tunnel, Hubble UI)
- **Gateway API**: v1.2.1

### **애드온 스택**
| 카테고리 | 컴포넌트 | 버전 | 용도 |
|---------|---------|------|------|
| 📦 Package | Helm | 3.x | 패키지 관리 |
| 💾 Storage | Longhorn | v1.7.2 (chart 1.7.2) | 분산 블록 스토리지 / 기본 StorageClass |
| 📊 Monitoring | kube-prometheus-stack | chart 79.9.0 | 메트릭 수집/시각화 |
| 📋 Logging | Loki + Promtail | loki-stack chart 2.10.3 | 로그 수집/조회 |
| 🔄 GitOps | ArgoCD | v2.13.2 | 선언적 배포 |
| 🔐 Secrets | Sealed Secrets | chart 2.17.9 (app 0.33.1) | 암호화된 Secret 관리 |
| 🔒 TLS | Cert-Manager | v1.16.2 | 인증서 자동화 |
| 📈 Metrics | Metrics Server | v0.7.2 | kubectl top 지원 |

---

## 🏗️ 프로젝트 구조

```
oci-k8s-production/
├── terraform/                          # 인프라 프로비저닝
│   ├── provider.tf                     # OCI Provider 설정
│   ├── variables.tf                    # 변수 정의
│   ├── terraform.tfvars                # 변수 값 (직접 생성)
│   ├── main.tf                         # VCN, Compute, Volume 리소스
│   └── outputs.tf                      # Ansible 인벤토리 자동 생성
│
├── ansible/                            # 구성 관리
│   ├── inventory/
│   │   ├── hosts.ini                   # Terraform이 자동 생성
│   │   └── group_vars/
│   │       ├── all.yml                 # 전역 변수 (버전 관리)
│   │       ├── k8s_master.yml          # Master 노드 변수
│   │       └── k8s_workers.yml         # Worker 노드 변수
│   │
│   ├── roles/                          # 15개 Role
│   │   ├── common/                     # 시스템 기본 설정
│   │   ├── containerd/                 # Container Runtime
│   │   ├── kubernetes/                 # kubeadm, kubelet, kubectl
│   │   ├── k8s-master/                 # Master 노드 초기화
│   │   ├── k8s-worker/                 # Worker 노드 조인
│   │   ├── cilium/                     # Cilium CNI (VXLAN, Hubble)
│   │   ├── gateway-api/                # Gateway API CRDs
│   │   ├── helm/                       # Helm 패키지 매니저
│   │   ├── longhorn/                   # Longhorn 분산 스토리지
│   │   ├── monitoring/                 # Prometheus + Grafana
│   │   ├── logging/                    # Loki + Promtail
│   │   ├── argocd/                     # ArgoCD GitOps
│   │   ├── sealed-secrets/             # Sealed Secrets
│   │   ├── cert-manager/               # Cert-Manager
│   │   └── metrics-server/             # Metrics Server
│   │
│   └── playbooks/
│       ├── site.yml                    # 초기 배포 (전체)
│       └── upgrade.yml                 # 버전 업그레이드
│
├── scripts/
│   ├── deploy.sh                       # 초기 배포 자동화
│   ├── upgrade.sh                      # 업그레이드 자동화
│   └── destroy.sh                      # 클러스터 삭제
│
└── docs/
    └── components.md                   # 컴포넌트 상세 설명
```

---

## 🚀 빠른 시작

### **1. 사전 준비**
```bash
terraform version  # >= 1.0
ansible --version  # >= 2.14
```

### **2. OCI 설정**
`terraform/terraform.tfvars` 생성:
```hcl
# OCI 인증
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaa******************"
user_ocid        = "ocid1.user.oc1..aaaaaaa******************"
fingerprint      = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99"
private_key_path = "/path/to/oci_api_key.pem"
region           = "ap-chuncheon-1"  # 또는 ap-seoul-1

compartment_ocid = "ocid1.tenancy.oc1..aaaaaaa******************"
ssh_public_key   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC******************"

# 클러스터 설정
cluster_name     = "k8s-prod"
master_count     = 1
worker_count     = 1

# 인스턴스 사양 (프리티어 최대)
instance_ocpus   = 2
instance_memory  = 12
```

**📌 OCI 정보 확인**:
- **Tenancy/User/Compartment OCID**: OCI Console → Profile → Tenancy/User Settings
- **Fingerprint**: Profile → API Keys → Add API Key
- **Private Key**: API Key 생성 시 다운로드한 `.pem` 파일 경로
- **SSH Public Key**: `ssh-keygen -t ed25519` 로 생성 후 `.pub` 파일 내용

### **3. 초기 배포 (처음 클러스터 구축)**
```bash
# 원클릭 (Terraform + Ansible 자동 실행)
./scripts/deploy.sh

# 또는 수동
cd terraform
terraform init
terraform apply -auto-approve

cd ../ansible
ansible-playbook playbooks/site.yml
```

**예상 소요 시간**: 약 20-30분

### **4. 접속**
```bash
# SSH
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip)

# kubeconfig
mkdir -p ~/.kube
scp ubuntu@<master-ip>:/home/ubuntu/.kube/config ~/.kube/config
kubectl get nodes
```

---

## 📊 서비스 접속

배포 완료 후 NodePort를 통해 접속:

| 서비스 | URL | 계정 | 비밀번호 확인 |
|--------|-----|------|-------------|
| **Grafana** | `http://<master-ip>:30000` | admin | `kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' \| base64 -d` |
| **Prometheus** | `http://<master-ip>:30090` | - | 인증 없음 |
| **ArgoCD** | `https://<master-ip>:30080` | admin | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| **Longhorn UI** | `http://<master-ip>:30088` | - | 인증 없음 |

---

## � 관리

### **클러스터 버전 업그레이드**

주기적으로 Kubernetes 및 애드온 버전을 업그레이드할 때 사용:

```bash
# 1. 버전 변경
vim ansible/inventory/group_vars/all.yml

# 예시: kubernetes_version: "1.35" → "1.36"
#      cilium_chart_version: "1.19.1" → "1.20.0"

# 2. 원클릭 업그레이드
./scripts/upgrade.sh

# 또는 수동
cd ansible
ansible-playbook playbooks/upgrade.yml
```

**업그레이드 프로세스**:
1. Kubernetes 컴포넌트 업그레이드 (kubeadm, kubelet, kubectl)
2. Master 노드: drain → kubeadm upgrade → uncordon
3. Worker 노드: 순차적으로 drain → upgrade → uncordon
4. 모든 애드온 Helm 차트 업그레이드

**예상 소요 시간**: 약 15-20분

> ⚠️ 업그레이드 중 일시적으로 워크로드가 재스케줄링될 수 있습니다.

### **워커 노드 추가**
```bash
# terraform/terraform.tfvars 수정
worker_count = 2

terraform apply
ansible-playbook playbooks/site.yml --limit k8s_workers
```

### **Sealed Secret 생성**
```bash
# 클러스터 공개키로 암호화
kubectl create secret generic mysecret \
  --dry-run=client --from-literal=password=mysecretpassword -o yaml | \
  kubeseal -o yaml > mysealedsecret.yaml

# Git에 커밋 후 ArgoCD가 자동 배포
```

### **클러스터 삭제**
```bash
cd terraform && terraform destroy -auto-approve
```

> ⚠️ Block Volume의 모든 데이터가 영구 삭제됩니다. 중요 데이터는 사전 백업 필수.

---

## 📈 리소스 (OCI Free Tier)

### **컴퓨트**
| 노드 | Shape | OCPU | Memory | 합계 |
|------|-------|------|--------|------|
| Master × 1 | VM.Standard.A1.Flex | 2 | 12GB | - |
| Worker × 1 | VM.Standard.A1.Flex | 2 | 12GB | - |
| **총합** | - | **4 / 4** | **24GB / 24GB** | ✅ 프리티어 한도 |

### **스토리지**
| 리소스 | 크기 | 개수 | 합계 |
|--------|------|------|------|
| Boot Volume | 50GB | 2 | 100GB |
| Block Volume (Longhorn) | 50GB | 2 | 100GB |
| **총합** | - | **4** | **200GB / 200GB** ✅ |

> OCI Free Tier는 Boot + Block Volume 합계 200GB 제공

### **네트워크**
| 리소스 | 사용 | 한도 |
|--------|------|------|
| VCN | 1 | 2 |
| Reserved Public IP | 1 (Master) | 1 |
| 아웃바운드 전송 | - | 10TB/월 |

**월 예상 비용: $0** (프리티어 한도 내 완전 무료)
