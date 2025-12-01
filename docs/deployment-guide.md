# OCI Kubernetes Production 배포 가이드

## 📋 사전 검증 체크리스트

### OCI Free Tier 제약사항 확인
- [ ] **Reserved Public IP**: 1개만 사용 가능 (Master Node)
- [ ] **OCPU 총합**: 4 OCPU 이하 (현재 설정: Master 2 + Worker 2 = 4 ✅)
- [ ] **메모리 총합**: 24GB 이하 (현재 설정: Master 12 + Worker 12 = 24 ✅)
- [ ] **Block Volume**: 200GB 이하 (현재 설정: Boot 100GB + Block 100GB = 200GB ✅)

### 필수 사전 준비
- [ ] OCI 계정 및 Tenancy OCID 확보
- [ ] Compartment 생성 및 OCID 확보
- [ ] API 키 생성 (`~/.oci/oci_api_key.pem`)
- [ ] SSH 키 생성 (`~/.ssh/id_rsa.pub`)
- [ ] Terraform 1.0+ 설치
- [ ] Ansible 2.14+ 설치

---

## 🚀 배포 실행 단계

### Phase 1: Terraform 인프라 프로비저닝 (5-10분)

```bash
cd c:\Users\taeku\Documents\GitHub\oci-k8s-production\terraform

# 1. terraform.tfvars 파일 생성
cp terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars  # 아래 값 입력
```

**terraform.tfvars 필수 값:**
```hcl
tenancy_ocid       = "ocid1.tenancy.oc1..aaa..."
user_ocid          = "ocid1.user.oc1..aaa..."
fingerprint        = "aa:bb:cc:..."
private_key_path   = "C:/Users/taeku/.oci/oci_api_key.pem"
region             = "ap-chuncheon-1"
compartment_ocid   = "ocid1.compartment.oc1..aaa..."
ssh_public_key     = "ssh-rsa AAAA...== taeku@..."

# 클러스터 설정 (기본값 사용 가능)
cluster_name     = "k8s-prod"
master_count     = 1  # 고정 (변경 불가)
worker_count     = 1  # 1-3 범위 가능
instance_ocpus   = 2
instance_memory  = 12
```

```powershell
# 2. Terraform 초기화
terraform init

# 3. 배포 계획 검증
terraform plan

# 예상 생성 리소스 (총 17개):
# - VCN, Subnet, IGW, Route Table, Security List
# - Master Instance (1), Worker Instance (1)
# - Reserved IP (1), Ephemeral IP (1)
# - Block Volumes (2), Volume Attachments (2)
# - Ansible Inventory (1)

# 4. 인프라 생성
terraform apply

# 출력 예시:
# master_public_ips = ["150.230.x.x"]
# worker_public_ips = ["140.238.y.y"]
# ssh_connection_commands = "ssh ubuntu@150.230.x.x"
```

**예상 결과:**
- ✅ Master Node: `k8s-prod-master` (Reserved IP: `150.230.x.x`)
- ✅ Worker Node: `k8s-prod-worker-1` (Ephemeral IP: `140.238.y.y`)
- ✅ Ansible Inventory 자동 생성: `../ansible/inventory/hosts.ini`

### Phase 2: Ansible 클러스터 구성 (20-30분)

```bash
cd ../ansible

# 1. Ansible Inventory 확인
cat inventory/hosts.ini

# 예상 출력:
# [k8s_master]
# master-1 ansible_host=150.230.x.x ansible_user=ubuntu
# 
# [k8s_workers]
# worker-1 ansible_host=140.238.y.y ansible_user=ubuntu

# 2. SSH 연결 테스트
ansible all -i inventory/hosts.ini -m ping

# 예상 출력:
# master-1 | SUCCESS => { "ping": "pong" }
# worker-1 | SUCCESS => { "ping": "pong" }
```

#### 옵션 A: 전체 자동 배포 (권장)
```bash
ansible-playbook playbooks/00-deploy-all.yml -i inventory/hosts.ini

# 실행 순서:
# Stage 1: Prepare All Nodes (10분)
#   - APT 업데이트
#   - iptables 초기화 (OCI REJECT 규칙 제거)
#   - 커널 모듈 로드
#   - containerd 설치
#
# Stage 2: Install Kubernetes (5분)
#   - kubeadm, kubelet, kubectl 설치
#
# Stage 3: Initialize Cluster (3분)
#   - Master kubeadm init
#   - Worker kubeadm join
#
# Stage 4: Install Cilium CNI (2분)
#   - Cilium CLI 설치
#   - Cilium 배포
#
# Stage 5-11: Install Addons (10-15분)
#   - Helm
#   - Gateway API
#   - Prometheus + Grafana
#   - Loki + Promtail
#   - ArgoCD
#   - Sealed Secrets
#   - Cert-Manager
```

#### 옵션 B: 단계별 수동 배포
```bash
# 기본 설정만 (Kubernetes + Cilium)
ansible-playbook playbooks/01-prepare-nodes.yml -i inventory/hosts.ini
ansible-playbook playbooks/02-install-k8s.yml -i inventory/hosts.ini
ansible-playbook playbooks/03-init-cluster.yml -i inventory/hosts.ini
ansible-playbook playbooks/04-install-cilium.yml -i inventory/hosts.ini

# 선택적으로 Addon 설치
ansible-playbook playbooks/07-install-monitoring.yml -i inventory/hosts.ini
```

### Phase 3: 배포 검증

```bash
# 1. kubeconfig 가져오기
scp ubuntu@150.230.x.x:/home/ubuntu/.kube/config ~/.kube/config

# 2. 클러스터 상태 확인
kubectl get nodes

# 예상 출력:
# NAME               STATUS   ROLES           AGE   VERSION
# k8s-prod-master    Ready    control-plane   5m    v1.31.x
# k8s-prod-worker-1  Ready    <none>          3m    v1.31.x

# 3. Pod 상태 확인
kubectl get pods -A

# 예상 출력 (Cilium만 설치 시):
# NAMESPACE     NAME                                     READY   STATUS
# kube-system   cilium-xxxxx                             1/1     Running
# kube-system   cilium-operator-xxxxx                    1/1     Running
# kube-system   coredns-xxxxx                            1/1     Running
# kube-system   kube-apiserver-k8s-prod-master           1/1     Running
# kube-system   kube-controller-manager-k8s-prod-master  1/1     Running
# kube-system   kube-proxy-xxxxx                         1/1     Running
# kube-system   kube-scheduler-k8s-prod-master           1/1     Running

# 4. Cilium 상태 확인
kubectl -n kube-system exec -it ds/cilium -- cilium status

# 5. Addon 접속 (전체 배포 시)
# Grafana: http://150.230.x.x:30000 (admin/admin)
# ArgoCD: https://150.230.x.x:30080 (admin/[kubectl -n argocd get secret...])
```

---

## ⚠️ 알려진 제약사항 및 해결 방법

### 1. Reserved IP 추가 생성 시 과금 발생
**문제**: `master_count > 1` 설정 시 Reserved IP 추가 생성
**해결**: Terraform validation으로 차단됨
```
Error: OCI Free Tier supports only 1 master node (1 Reserved IP limit).
```

### 2. OCPU 한도 초과
**문제**: `instance_ocpus * (master_count + worker_count) > 4`
**해결**: Terraform validation으로 차단됨
```
Error: Total OCPU count exceeds Free Tier limit (4 OCPU).
```

### 3. APT Lock 충돌
**문제**: Cloud-init 실행 중 APT 사용 불가
**해결**: `common` role에 APT lock 대기 로직 포함됨

### 4. OCI iptables REJECT 규칙
**문제**: Kubernetes 네트워킹 차단
**해결**: `common` role에서 자동 제거 (`oracle-cloud-agent` 비활성화)

### 5. Ansible 연결 실패
**문제**: SSH 키 권한 오류 (Windows)
**해결**:
```powershell
icacls C:\Users\taeku\.ssh\id_rsa /inheritance:r
icacls C:\Users\taeku\.ssh\id_rsa /grant:r "$($env:USERNAME):(R)"
```

---

## 🔍 트러블슈팅

### Terraform 실패 시
```bash
# 로그 확인
terraform apply -auto-approve

# 특정 리소스만 재생성
terraform taint oci_core_instance.k8s_master[0]
terraform apply

# 완전 삭제 후 재시작
terraform destroy -auto-approve
terraform apply -auto-approve
```

### Ansible 실패 시
```bash
# 특정 단계만 재실행
ansible-playbook playbooks/01-prepare-nodes.yml -i inventory/hosts.ini --limit master-1

# Verbose 모드로 디버깅
ansible-playbook playbooks/03-init-cluster.yml -i inventory/hosts.ini -vvv

# SSH 직접 연결 확인
ssh -i ~/.ssh/id_rsa ubuntu@150.230.x.x
```

### Kubernetes 클러스터 초기화
```bash
# Master 노드에서 실행
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube

# Worker 노드에서 실행
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet
```

---

## 📊 배포 후 리소스 사용량

| 리소스 | 사용량 | Free Tier 한도 | 여유 |
|--------|--------|----------------|------|
| OCPU | 4 | 4 | 0 (100%) |
| Memory | 24GB | 24GB | 0 (100%) |
| Boot Volume | 100GB | 200GB | 100GB (50%) |
| Block Volume | 100GB | 200GB | 100GB (50%) |
| Reserved IP | 1 | 1 | 0 (100%) |
| Ephemeral IP | 1 | 무제한 | ∞ |

**⚠️ 주의**: 모든 무료 리소스를 최대로 사용하는 구성입니다.

---

## 🧹 정리 (Clean Up)

```bash
# 1. Kubernetes Addon 제거 (선택)
kubectl delete namespace monitoring logging argocd cert-manager

# 2. Terraform 인프라 전체 삭제
cd c:\Users\taeku\Documents\GitHub\oci-k8s-production\terraform
terraform destroy -auto-approve

# 삭제되는 리소스:
# - 모든 컴퓨트 인스턴스
# - Reserved/Ephemeral IP
# - Block Volumes
# - VCN 및 네트워크 리소스
```

---

## 📝 다음 단계

1. **GitOps 설정**: ArgoCD로 애플리케이션 배포
2. **도메인 연결**: DNS A 레코드 → Master IP
3. **TLS 인증서**: Cert-Manager + Let's Encrypt 설정
4. **모니터링 알림**: Prometheus AlertManager 구성
5. **로깅 대시보드**: Grafana + Loki 데이터소스 연결
