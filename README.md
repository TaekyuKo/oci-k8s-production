# OCI Kubernetes Production Cluster

**Terraform + Ansible 기반 프로덕션급 Kubernetes 클러스터 자동화**

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-blue?logo=terraform)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-%3E%3D2.14-red?logo=ansible)](https://www.ansible.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![OCI](https://img.shields.io/badge/OCI-Free%20Tier-red?logo=oracle)](https://www.oracle.com/cloud/free/)

Oracle Cloud Infrastructure에서 Terraform과 Ansible을 활용한 프로덕션급 Kubernetes 클러스터 완전 자동 구축.

---

## 🎯 특징

- ⚡ **원클릭 배포**: 인프라부터 애드온까지 완전 자동화
- 📊 **Observability**: Prometheus, Grafana, Loki 기본 탑재
- 🚀 **GitOps Ready**: ArgoCD로 즉시 CD 파이프라인 구축
- 💰 **프리티어**: OCI Free Tier 범위 내 무료 운영

---

## 📦 기술 스택

### **인프라 (Terraform)**
- VCN + Subnet + Security List
- Compute Instances (ARM64 Ampere A1)
- Block Volumes
- Reserved Public IP

### **Kubernetes 기본**
- **Runtime**: containerd 1.7.28
- **Kubernetes**: v1.31.14
- **CNI**: Cilium v1.16.5 (eBPF, VXLAN tunnel)
- **Gateway API**: Kubernetes Gateway API CRDs

### **애드온 스택**
| 카테고리 | 컴포넌트 | 버전 | 용도 |
|---------|---------|------|------|
| 📦 Package | Helm | 3.19.2 | 패키지 관리 |
| 📊 Monitoring | Prometheus + Grafana | - | 메트릭 수집/시각화 |
| 📋 Logging | Loki + Promtail | - | 로그 수집/조회 |
| 🔄 GitOps | ArgoCD | - | 선언적 배포 |
| 🔐 Secrets | Sealed Secrets | - | 암호화된 Secret 관리 |
| 🔒 TLS | Cert-Manager | - | 인증서 자동화 |
| 📈 Metrics | Metrics Server | - | kubectl top 지원 |

---

## 🏗️ 프로젝트 구조

```
oci-k8s-production/
├── terraform/           # 인프라 코드
│   ├── main.tf         # VCN, Compute, Volumes
│   ├── provider.tf     # OCI Provider
│   ├── variables.tf    # 입력 변수
│   └── outputs.tf      # Ansible 인벤토리 자동 생성
│
├── ansible/
│   ├── inventory/      # hosts.ini (Terraform 자동 생성)
│   ├── roles/          # 14개 Role (common, k8s, addons)
│   └── playbooks/      # 12개 플레이북 (순차 실행)
│
└── scripts/
    └── deploy.sh       # 전체 자동 배포
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
private_key_path = "C:\\Users\\<username>\\OCI_Security\\oci_api_key.pem"
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
- **Private Key**: API Key 생성 시 다운로드한 `.pem` 파일 경로 (Windows는 `\\` 사용)
- **SSH Public Key**: `ssh-keygen -t rsa -b 2048` 로 생성 후 `.pub` 파일 내용

### **3. 배포 (원클릭)**
```bash
./scripts/deploy.sh
```

또는 수동:
```bash
cd terraform && terraform apply -auto-approve
cd ../ansible && ansible-playbook playbooks/00-deploy-all.yml
```

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

| 서비스 | URL | 비밀번호 확인 |
|--------|-----|-------------|
| **Grafana** | `http://<master-ip>:30000` | `kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' \| base64 -d` |
| **Prometheus** | `http://<master-ip>:30090` | - |
| **ArgoCD** | `https://<master-ip>:30080` | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |

---

## 🔧 관리

### **워커 노드 추가**
```bash
# terraform/terraform.tfvars 수정
worker_count = 3

terraform apply
ansible-playbook ansible/playbooks/02-install-k8s.yml --limit k8s_workers
```

### **애드온 재설치**
```bash
ansible-playbook ansible/playbooks/07-install-monitoring.yml
ansible-playbook ansible/playbooks/09-install-argocd.yml
```

### **Block Volume 마운트 (추가 스토리지)**

Terraform이 각 노드에 50GB Block Volume을 생성했습니다. 사용하려면 iSCSI로 연결 후 마운트해야 합니다.

#### **1. iSCSI 명령어 확인 (OCI 콘솔)**
1. **Compute** → **Instances** → 해당 노드 클릭
2. **Resources** → **Attached Block Volumes**
3. Block Volume 이름 클릭 → **iSCSI Commands and Information** 탭
4. 표시된 **3개 명령어** 복사

#### **2. iSCSI 연결 (각 노드에서 실행)**
```bash
# SSH로 노드 접속
ssh ubuntu@<node-ip>

# OCI 콘솔에서 복사한 명령어 3개 실행 (예시 - 실제 값은 콘솔에서 확인)
sudo iscsiadm -m node -o new -T iqn.2015-12.com.oracleiaas:xxxxxx -p xxx.xxx.x.x:3260
sudo iscsiadm -m node -o update -T iqn.2015-12.com.oracleiaas:xxxxxx -n node.startup -v automatic
sudo iscsiadm -m node -T iqn.2015-12.com.oracleiaas:xxxxxx -p xxx.xxx.x.x:3260 -l

# 연결된 디스크 확인
lsblk
# 출력: sdb (50GB) 확인
```

#### **3. 파일시스템 생성 및 마운트 (최초 1회)**
```bash
# 파일시스템 생성
sudo mkfs.ext4 /dev/sdb

# 마운트 포인트 생성
sudo mkdir -p /data

# 마운트
sudo mount /dev/sdb /data

# 재부팅 후 자동 마운트 설정
UUID=$(sudo blkid -s UUID -o value /dev/sdb)
echo "UUID=$UUID /data ext4 defaults,nofail,_netdev 0 2" | sudo tee -a /etc/fstab

# 확인
df -h /data
```

#### **4. 사용 예시**
```bash
# Prometheus 데이터 디렉토리로 사용
sudo mkdir -p /data/prometheus
sudo chown -R 65534:65534 /data/prometheus  # nobody:nogroup

# Loki 데이터 디렉토리로 사용
sudo mkdir -p /data/loki
sudo chown -R 10001:10001 /data/loki

# 일반 애플리케이션 PV로 사용
sudo mkdir -p /data/apps
sudo chmod 777 /data/apps
```

> 💡 **Tip**: `/data` 디렉토리는 컨테이너에서 hostPath로 마운트하여 영구 스토리지로 활용 가능

### **클러스터 삭제**
```bash
cd terraform && terraform destroy -auto-approve
```

> ⚠️ **주의**: Block Volume의 모든 데이터가 영구 삭제됩니다. 중요 데이터는 사전 백업 필수!

---

## 📈 리소스 (OCI Free Tier)

### **컴퓨트 (Compute)**
| 리소스 | 노드 | 개수 | OCPU/노드 | Memory/노드 | 합계 OCPU | 합계 Memory |
|--------|------|------|-----------|-------------|-----------|-------------|
| Master | VM.Standard.A1.Flex | 1 | 2 | 12GB | 2 | 12GB |
| Worker | VM.Standard.A1.Flex | 1 | 2 | 12GB | 2 | 12GB |
| **총합** | - | **2** | - | - | **4 / 4** | **24GB / 24GB** |

### **스토리지 (Storage)**
| 리소스 | 노드당 크기 | 개수 | 총 사용량 | 프리티어 한도 |
|--------|------------|------|-----------|--------------|
| Boot Volume | 50GB | 2 | 100GB | - |
| Block Volume | 50GB | 2 | 100GB | - |
| **총합** | - | **4** | **200GB** | **200GB (통합)** |

> 💡 OCI Free Tier는 Boot + Block Volume 합계 200GB 제공 (각각 100GB 아님)

### **네트워크 (Network)**
| 리소스 | 사용량 | 프리티어 한도 |
|--------|--------|--------------|
| VCN | 1 | 2 |
| Subnet | 1 | VCN당 제한 없음 |
| Internet Gateway | 1 | VCN당 1개 |
| Reserved Public IP | 1 (Master) | 1 |
| Ephemeral Public IP | 1 (Worker) | 제한 없음 |
| **아웃바운드 데이터 전송** | - | **10TB/월** |

### **💰 비용 예상**
- **프리티어 사용률**: OCPU 100% (4/4), Memory 100% (24GB/24GB), Storage 100% (200GB/200GB)
- **월 예상 비용**: **$0** (완전 무료)
- **주의사항**: 프리티어 한도 초과 시 자동 과금 (노드 추가 시 주의)

---

## 📄 License

MIT License
