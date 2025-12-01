# OCI Kubernetes Production Environment

**프로덕션급 Kubernetes 클러스터 자동화 with Terraform + Ansible**

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-blue?logo=terraform)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-%3E%3D2.14-red?logo=ansible)](https://www.ansible.com/)
[![OCI](https://img.shields.io/badge/OCI-Free%20Tier-red?logo=oracle)](https://www.oracle.com/cloud/free/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31-326CE5?logo=kubernetes)](https://kubernetes.io/)

Oracle Cloud Infrastructure에서 Terraform과 Ansible을 활용한 프로덕션급 Kubernetes 클러스터 자동 구축 프로젝트입니다.

---

## 🎯 프로젝트 목표

- **완전 자동화**: 인프라부터 애드온까지 원클릭 배포
- **프로덕션 준비**: 모니터링, 로깅, GitOps 기본 탑재
- **확장 가능**: Role 기반 구조로 쉬운 커스터마이징
- **재실행 가능**: Ansible의 멱등성으로 안전한 재배포

---

## 📦 포함된 컴포넌트

### **인프라 (Terraform)**
- VCN, Subnet, Security List
- Compute Instances (Master + Workers)
- Block Volumes
- Reserved/Ephemeral Public IPs

### **Kubernetes 기본 (Ansible)**
- ✅ **Container Runtime**: containerd
- ✅ **Kubernetes**: v1.31 (kubeadm, kubelet, kubectl)
- ✅ **CNI**: Cilium (eBPF 기반, 고성능)
- ✅ **Gateway API**: Kubernetes Gateway API (Nginx Ingress 대체)

### **핵심 애드온 (Ansible)**
- 📊 **Monitoring**: Prometheus + Grafana (메트릭 수집/시각화)
- 📋 **Logging**: Loki + Promtail (경량 로깅 스택)
- 🔄 **GitOps**: ArgoCD (자동 배포 & CD)
- 📦 **Package Manager**: Helm
- 🔐 **Secret Management**: Sealed Secrets (암호화된 Secret 관리)
- 🔒 **Certificate**: Cert-Manager (Let's Encrypt 자동 SSL)
- 📈 **Metrics**: Metrics Server (kubectl top 지원)

### **학습 목적에 최적화**
- ✅ **CICD 파이프라인**: ArgoCD로 GitOps 워크플로우 학습
- ✅ **모니터링**: Prometheus + Grafana로 실시간 메트릭 수집
- ✅ **로깅**: Loki로 중앙화된 로그 관리
- ✅ **보안**: Sealed Secrets로 안전한 Secret 관리 패턴
- ✅ **네트워킹**: Cilium eBPF + Gateway API로 최신 트렌드 학습
- ✅ **리소스 관리**: Metrics Server로 kubectl top 사용

---

## 🏗️ 프로젝트 구조

```
oci-k8s-production/
│
├─── terraform/                          # 인프라 프로비저닝
│    ├── provider.tf                     # OCI Provider 설정
│    ├── variables.tf                    # 변수 정의
│    ├── terraform.tfvars                # 변수 값 (.gitignore)
│    ├── main.tf                         # 리소스 정의
│    ├── outputs.tf                      # Ansible로 전달할 출력값
│    └── inventory.tf                    # Ansible 인벤토리 자동 생성
│
├─── ansible/                            # 구성 관리
│    │
│    ├── inventory/
│    │   ├── hosts.ini                   # Terraform이 자동 생성
│    │   └── group_vars/
│    │       ├── all.yml                 # 전역 변수
│    │       ├── k8s_master.yml
│    │       └── k8s_workers.yml
│    │
│    ├── roles/
│    │   ├── common/                     # 기본 시스템 설정
│    │   ├── containerd/                 # Container Runtime
│    │   ├── kubernetes/                 # K8s 기본 설치
│    │   ├── k8s-master/                 # Master 노드 초기화
│    │   ├── k8s-worker/                 # Worker 노드 조인
│    │   ├── cilium/                     # CNI (eBPF)
│    │   ├── gateway-api/                # Kubernetes Gateway API
│    │   ├── helm/                       # Helm 설치
│    │   ├── monitoring/                 # Prometheus + Grafana
│    │   ├── logging/                    # Loki + Promtail
│    │   ├── argocd/                     # GitOps
│    │   ├── sealed-secrets/             # Secret 암호화
│    │   └── cert-manager/               # SSL 인증서 자동화
│    │
│    └── playbooks/
│        ├── 00-deploy-all.yml           # 전체 배포 (한 번에)
│        ├── 01-prepare-nodes.yml        # 노드 준비
│        ├── 02-install-k8s.yml          # Kubernetes 설치
│        ├── 03-init-cluster.yml         # 클러스터 초기화
│        ├── 04-install-cilium.yml       # CNI 설치
│        ├── 05-install-helm.yml         # Helm 설치
│        ├── 06-install-gateway-api.yml  # Gateway API
│        ├── 07-install-monitoring.yml   # Prometheus + Grafana
│        ├── 08-install-logging.yml      # Loki + Promtail
│        ├── 09-install-argocd.yml       # ArgoCD
│        ├── 10-install-secrets.yml      # Sealed Secrets
│        └── 11-install-cert-manager.yml # Cert-Manager
│
├─── scripts/
│    ├── deploy.sh                       # 전체 자동 배포
│    ├── destroy.sh                      # 전체 삭제
│    └── update-addons.sh                # 애드온만 업데이트
│
├─── docs/
│    ├── architecture.md                 # 아키텍처 설명
│    ├── components.md                   # 컴포넌트 상세
│    └── troubleshooting.md              # 문제 해결
│
├─── .gitignore
├─── LICENSE
└─── README.md
```

---

## 🚀 빠른 시작

### **사전 준비**

```bash
# 필수 도구 설치 확인
terraform version  # >= 1.0
ansible --version  # >= 2.14
```

### **1단계: Terraform 변수 설정**

`terraform/terraform.tfvars` 생성:

```hcl
# OCI 인증
tenancy_ocid     = "ocid1.tenancy.oc1..xxx"
user_ocid        = "ocid1.user.oc1..xxx"
fingerprint      = "aa:bb:cc:..."
private_key_path = "~/.oci/oci_api_key.pem"
region           = "ap-seoul-1"

# 리소스
compartment_ocid = "ocid1.compartment.oc1..xxx"
ssh_public_key   = "ssh-rsa AAAAB3..."

# 클러스터 설정 (선택)
master_count     = 1
worker_count     = 2
instance_ocpus   = 2
instance_memory  = 12
```

### **2단계: 자동 배포**

```bash
# 전체 자동 배포 (한 번에)
./scripts/deploy.sh

# 또는 단계별 실행
cd terraform && terraform apply
cd ../ansible && ansible-playbook playbooks/00-deploy-all.yml
```

### **3단계: 클러스터 접속**

```bash
# Master 노드 SSH
ssh ubuntu@$(terraform output -raw master_public_ip)

# kubectl 설정 가져오기
mkdir -p ~/.kube
scp ubuntu@<master-ip>:/home/ubuntu/.kube/config ~/.kube/config

# 클러스터 확인
kubectl get nodes
kubectl get pods -A
```

---

## 📊 배포 후 접속 정보

### **ArgoCD**
```bash
# ArgoCD 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 접속: https://<master-ip>:30080
# ID: admin
# PW: (위에서 확인한 비밀번호)
```

### **Grafana**
```bash
# Grafana 비밀번호 확인
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d

# 접속: http://<master-ip>:30000
# ID: admin
# PW: (위에서 확인한 비밀번호)
```

### **Prometheus**
```bash
# 접속: http://<master-ip>:30090
```

---

## 🎨 커스터마이징

### **워커 노드 추가**

`terraform/terraform.tfvars`:
```hcl
worker_count = 3  # 2 → 3으로 변경
```

```bash
terraform apply
ansible-playbook ansible/playbooks/02-install-k8s.yml --limit k8s_workers
```

### **애드온만 재설치**

```bash
# 모니터링만 재설치
ansible-playbook ansible/playbooks/07-install-monitoring.yml

# ArgoCD만 재설치
ansible-playbook ansible/playbooks/09-install-argocd.yml
```

---

## 🔧 기술 스택 선정 이유

| 컴포넌트 | 선택 | 이유 |
|---------|------|------|
| **CNI** | Cilium | eBPF 기반 고성능, NetworkPolicy 지원, 관측성 우수 |
| **Ingress** | Gateway API | Kubernetes 표준, Nginx Ingress 후속, 멀티 벤더 지원 |
| **Monitoring** | Prometheus + Grafana | 사실상 표준, CNCF 졸업 프로젝트 |
| **Logging** | Loki + Promtail | Prometheus와 통합, 경량, 저렴한 스토리지 |
| **GitOps** | ArgoCD | 선언적 배포, Git을 Single Source of Truth |
| **Secrets** | Sealed Secrets | Git에 안전하게 Secret 저장, ArgoCD 통합 |
| **Certificates** | Cert-Manager | Let's Encrypt 자동화, 인증서 갱신 자동화 |

---

## 📈 리소스 사용량

| 리소스 | 기본 구성 | 프리티어 한도 |
|--------|----------|--------------|
| OCPU | 4 (Master 2 + Workers 2) | 4 |
| Memory | 24GB (각 12GB) | 24GB |
| Block Volume | 150GB | 200GB |
| Reserved IP | 1 | 1 |

**💰 비용**: 프리티어 범위 내 $0/월

---

## 🧹 리소스 정리

```bash
# 전체 삭제
./scripts/destroy.sh

# 또는
ansible-playbook ansible/playbooks/99-destroy.yml
cd terraform && terraform destroy
```

---

## 📚 학습용 간단 버전

프로덕션 환경이 부담스럽다면 학습용 간단 버전을 먼저 시도해보세요:

👉 **[oci-k8s-terraform](https://github.com/TaekyuKo/oci_k8s_terraform)** - 30분 만에 클러스터 구축

---

## 🤝 Contributing

버그 리포트, 기능 제안, PR 환영합니다!

---

## 📄 License

MIT License - 자유롭게 사용하세요.

---

## ⚠️ 주의사항

1. **프리티어 한도**: 기본 구성이 프리티어를 100% 사용합니다
2. **애드온 리소스**: 모든 애드온 설치 시 메모리 사용량 증가 (약 4-6GB)
3. **비용**: 프리티어 초과 시 과금될 수 있으니 모니터링하세요
4. **보안**: 프로덕션 사용 시 Security List 세밀하게 조정 필요
5. **백업**: Sealed Secrets 마스터 키는 안전하게 백업하세요
