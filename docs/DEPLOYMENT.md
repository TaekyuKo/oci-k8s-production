# OCI Kubernetes Production 배포 가이드

## 🚀 전체 배포 프로세스

### ✅ **사전 준비 체크리스트**

```powershell
# 1. 필수 도구 설치 확인
terraform version  # 1.0 이상
ansible --version  # 2.14 이상

# 2. OCI 계정 정보 준비
# - Tenancy OCID
# - User OCID
# - API Key Fingerprint
# - API Private Key (~/.oci/oci_api_key.pem)
# - Compartment OCID
# - SSH Public Key (~/.ssh/id_rsa.pub)
```

---

## 📋 **Step 1: Terraform 변수 설정**

### 1-1. terraform.tfvars 파일 생성

```powershell
cd c:\Users\taeku\Documents\GitHub\oci-k8s-production\terraform
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
```

### 1-2. 필수 값 입력

```hcl
# ========================================
# OCI 인증 정보
# ========================================
tenancy_ocid       = "ocid1.tenancy.oc1..aaaaaaaXXXXXX"
user_ocid          = "ocid1.user.oc1..aaaaaaaXXXXXX"
fingerprint        = "aa:bb:cc:dd:ee:ff:..."
private_key_path   = "C:/Users/taeku/.oci/oci_api_key.pem"
region             = "ap-chuncheon-1"

# ========================================
# 리소스 위치
# ========================================
compartment_ocid   = "ocid1.compartment.oc1..aaaaaaaXXXXXX"

# ========================================
# SSH 접속 키
# ========================================
ssh_public_key     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... taeku@DESKTOP"

# ========================================
# 클러스터 설정 (기본값 사용 가능)
# ========================================
cluster_name       = "k8s-prod"
master_count       = 1  # 고정 (변경 불가)
worker_count       = 1  # 1만 가능 (Free Tier)
instance_ocpus     = 2
instance_memory    = 12
boot_volume_size   = 50
block_volume_size  = 50
```

---

## 🏗️ **Step 2: Terraform 인프라 배포 (5-10분)**

```powershell
cd c:\Users\taeku\Documents\GitHub\oci-k8s-production\terraform

# 2-1. Terraform 초기화
terraform init

# 2-2. 배포 계획 확인
terraform plan

# 예상 출력:
# Plan: 17 to add, 0 to change, 0 to destroy.

# 2-3. 인프라 생성 실행
terraform apply

# "yes" 입력하여 승인
```

### 생성되는 리소스 (총 17개)

| 리소스 타입 | 수량 | 이름 | 설명 |
|-----------|------|------|------|
| **네트워크** | 5 | | |
| VCN | 1 | `k8s-prod-vcn` | 10.0.0.0/16 |
| Subnet | 1 | `k8s-prod-public-subnet` | 10.0.1.0/24 |
| Internet Gateway | 1 | `k8s-prod-igw` | |
| Route Table | 1 | `k8s-prod-public-rt` | |
| Security List | 1 | `k8s-prod-cluster-sl` | SSH, K8s API, HTTP/HTTPS 허용 |
| **컴퓨트** | 8 | | |
| Master Instance | 1 | `k8s-master` | 2 OCPU, 12GB RAM |
| Worker Instance | 1 | `k8s-worker` | 2 OCPU, 12GB RAM |
| Reserved IP | 1 | `k8s-master-ip` | Master 전용 |
| Master Block Volume | 1 | `k8s-master-bv` | 50GB |
| Worker Block Volume | 1 | `k8s-worker-bv` | 50GB |
| Volume Attachments | 2 | | |
| Data Sources | 1 | `hosts.ini` | Ansible 인벤토리 |

### 배포 완료 후 출력

```hcl
Outputs:

master_public_ips = [
  "150.230.45.123",
]
worker_public_ips = [
  "140.238.78.234",
]
primary_master_ip = "150.230.45.123"

ssh_connection_commands = <<EOT
# Master nodes (Reserved IPs)
ssh ubuntu@150.230.45.123  # k8s-master

# Worker nodes (Ephemeral IPs)
ssh ubuntu@140.238.78.234  # k8s-worker
EOT
```

### 검증

```powershell
# SSH 연결 테스트
ssh ubuntu@150.230.45.123

# 인스턴스 내부에서 확인
hostname  # k8s-master
```

---

## 🔧 **Step 3: Ansible 클러스터 구성 (20-30분)**

### 3-1. Ansible Inventory 확인

```powershell
cd ..\ansible
cat inventory\hosts.ini
```

**예상 출력:**
```ini
[k8s_master]
k8s-master ansible_host=150.230.45.123 ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[k8s_workers]
k8s-worker ansible_host=140.238.78.234 ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[k8s_all:children]
k8s_master
k8s_workers

[k8s_all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### 3-2. SSH 연결 테스트

```powershell
ansible all -i inventory\hosts.ini -m ping
```

**예상 출력:**
```
k8s-master | SUCCESS => {
    "ping": "pong"
}
k8s-worker | SUCCESS => {
    "ping": "pong"
}
```

### 3-3. 전체 자동 배포 실행

```powershell
ansible-playbook playbooks\00-deploy-all.yml -i inventory\hosts.ini
```

### 실행 단계별 설명 (총 11 Stage)

#### **Stage 1: Prepare All Nodes (10분)**
- APT 패키지 업데이트
- **OCI iptables REJECT 규칙 제거** ⭐
- oracle-cloud-agent 비활성화
- Kubernetes iptables 규칙 설정
- Swap 비활성화
- 커널 모듈 로드 (overlay, br_netfilter)
- containerd 설치 및 SystemdCgroup 활성화

**주요 작업:**
```yaml
- Remove OCI REJECT rules from iptables
- Set iptables policies to ACCEPT
- Configure K8s-specific iptables rules (SSH, API, NodePort)
- Install containerd with systemd cgroup driver
```

#### **Stage 2: Install Kubernetes (5분)**
- Kubernetes APT repository 추가
- kubeadm, kubelet, kubectl v1.31 설치
- 패키지 버전 고정 (apt-mark hold)

#### **Stage 3: Initialize Cluster (3분)**
- **Master**: `kubeadm init --pod-network-cidr=192.168.0.0/16`
- kubeconfig 생성 (`/home/ubuntu/.kube/config`)
- **Master taint 제거** (Pod 스케줄링 허용) ⭐
- Join command 생성
- **Worker**: `kubeadm join` 실행
- **Worker role 라벨 부여** ⭐

**예상 로그:**
```
TASK [k8s-master : Remove master node taint]
changed: [k8s-master]

TASK [k8s-worker : Label worker node with worker role]
changed: [k8s-worker]
```

#### **Stage 4: Install Cilium CNI (2분)**
- Cilium CLI 다운로드 및 설치
- Cilium CNI 배포 (eBPF 기반)
- Cilium Pod 대기

#### **Stage 5: Install Helm (1분)**
- Helm 3 설치
- Helm 리포지토리 추가
  - prometheus-community
  - grafana
  - argo
  - jetstack
  - sealed-secrets

#### **Stage 6: Install Gateway API (1분)**
- Gateway API CRDs 설치
- Gateway 컨트롤러 배포 대기

#### **Stage 7: Install Monitoring (5분)**
- Prometheus + Grafana 설치
- NodePort 설정:
  - Prometheus: 30090
  - Grafana: 30000
- Grafana 초기 비밀번호: `admin`

#### **Stage 8: Install Logging (3분)**
- Loki + Promtail 설치
- Loki PersistentVolume 생성 (10Gi)

#### **Stage 9: Install ArgoCD (3분)**
- ArgoCD 네임스페이스 생성
- ArgoCD 매니페스트 배포
- ArgoCD Server NodePort 패치 (30080)

#### **Stage 10: Install Sealed Secrets (2분)**
- Sealed Secrets Controller 설치
- kubeseal CLI 다운로드

#### **Stage 11: Install Cert-Manager (2분)**
- Cert-Manager CRDs 설치
- Cert-Manager 컨트롤러 배포

### 배포 완료 메시지

```
TASK [Display completion message]
ok: [localhost] => {
    "msg": [
        "=========================================",
        "✅ Kubernetes Production Cluster Ready!",
        "=========================================",
        "",
        "Next steps:",
        "  1. Configure kubectl:",
        "     scp ubuntu@150.230.45.123:/home/ubuntu/.kube/config ~/.kube/config",
        "",
        "  2. Access ArgoCD:",
        "     https://150.230.45.123:30080",
        "     Get password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d",
        "",
        "  3. Access Grafana:",
        "     http://150.230.45.123:30000",
        "     Get password: kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' | base64 -d",
        "",
        "========================================="
    ]
}
```

---

## 🎯 **Step 4: 클러스터 검증**

### 4-1. kubeconfig 가져오기

```powershell
# Master 노드에서 로컬로 복사
scp ubuntu@150.230.45.123:/home/ubuntu/.kube/config $env:USERPROFILE\.kube\config
```

### 4-2. 클러스터 상태 확인

```powershell
kubectl get nodes
```

**기대 결과:**
```
NAME         STATUS   ROLES           AGE   VERSION
k8s-master   Ready    control-plane   15m   v1.31.4
k8s-worker   Ready    worker          13m   v1.31.4
```

**주요 확인 사항:**
- ✅ `k8s-master`: **control-plane** 역할
- ✅ `k8s-worker`: **worker** 역할 표시
- ✅ 두 노드 모두 **Ready** 상태
- ✅ Master에도 taint 없음 (Pod 스케줄링 가능)

### 4-3. Pod 상태 확인

```powershell
kubectl get pods -A
```

**기대 결과 (전체 배포 시 약 40-50개 Pod):**

```
NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
argocd        argocd-application-controller-xxx         1/1     Running   0          5m
argocd        argocd-server-xxx                         1/1     Running   0          5m
cert-manager  cert-manager-xxx                          1/1     Running   0          3m
cert-manager  cert-manager-cainjector-xxx               1/1     Running   0          3m
cert-manager  cert-manager-webhook-xxx                  1/1     Running   0          3m
kube-system   cilium-xxx                                1/1     Running   0          12m
kube-system   cilium-operator-xxx                       1/1     Running   0          12m
kube-system   coredns-xxx                               1/1     Running   0          15m
kube-system   kube-apiserver-k8s-master                 1/1     Running   0          15m
kube-system   kube-controller-manager-k8s-master        1/1     Running   0          15m
kube-system   kube-proxy-xxx                            1/1     Running   0          15m
kube-system   kube-scheduler-k8s-master                 1/1     Running   0          15m
kube-system   sealed-secrets-controller-xxx             1/1     Running   0          4m
logging       loki-0                                    1/1     Running   0          6m
logging       loki-promtail-xxx                         1/1     Running   0          6m
monitoring    prometheus-grafana-xxx                    2/2     Running   0          7m
monitoring    prometheus-kube-prometheus-operator-xxx   1/1     Running   0          7m
monitoring    prometheus-kube-state-metrics-xxx         1/1     Running   0          7m
monitoring    prometheus-prometheus-node-exporter-xxx   1/1     Running   0          7m
```

### 4-4. Cilium 상태 확인

```powershell
kubectl -n kube-system exec -it ds/cilium -- cilium status
```

**기대 결과:**
```
KVStore:                Ok   Disabled
Kubernetes:             Ok   1.31 (v1.31.4) [linux/arm64]
Kubernetes APIs:        ["networking.k8s.io/v1::NetworkPolicy"]
BandwidthManager:       Ok   EDT with BPF
Host Routing:           Ok   BPF
CNI Config file:        Ok
Cilium:                 Ok   1.16.5 (v1.16.5)
NodeMonitor:            Ok   Listening for events on 2 CPUs
```

### 4-5. Taint 확인 (중요!)

```powershell
kubectl describe node k8s-master | Select-String "Taints"
```

**기대 결과:**
```
Taints:             <none>
```
✅ **Taint가 없어야 정상** → Master 노드에 Pod 배포 가능

### 4-6. Node 역할 확인

```powershell
kubectl get nodes --show-labels | Select-String "role"
```

**기대 결과:**
```
k8s-master   ...node-role.kubernetes.io/control-plane=...
k8s-worker   ...node-role.kubernetes.io/worker=worker...
```

---

## 🌐 **Step 5: 웹 접속 확인**

### 5-1. Grafana 접속

```powershell
# 비밀번호 확인
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# 브라우저 열기
Start-Process "http://150.230.45.123:30000"

# 로그인
# ID: admin
# PW: (위에서 확인한 비밀번호)
```

### 5-2. ArgoCD 접속

```powershell
# 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# 브라우저 열기
Start-Process "https://150.230.45.123:30080"

# 로그인
# ID: admin
# PW: (위에서 확인한 비밀번호)
```

### 5-3. Prometheus 접속

```powershell
Start-Process "http://150.230.45.123:30090"
```

---

## 📊 **최종 클러스터 구성 요약**

### 인프라 리소스

| 항목 | 값 | 비고 |
|------|-----|------|
| **Master Node** | k8s-master | 150.230.45.123 (Reserved IP) |
| **Worker Node** | k8s-worker | 140.238.78.234 (Ephemeral IP) |
| **OCPU** | 4 (각 2) | Free Tier 100% 사용 |
| **Memory** | 24GB (각 12GB) | Free Tier 100% 사용 |
| **Boot Volume** | 100GB (각 50GB) | |
| **Block Volume** | 100GB (각 50GB) | |

### Kubernetes 구성

| 구성요소 | 버전 | 상태 |
|---------|------|------|
| Kubernetes | v1.31.4 | ✅ |
| Container Runtime | containerd | ✅ |
| CNI | Cilium 1.16.5 | ✅ (eBPF) |
| Gateway API | 1.2.1 | ✅ |
| Helm | 3.x | ✅ |

### 설치된 Addon

| Addon | 버전 | 접속 포트 | 상태 |
|-------|------|-----------|------|
| Prometheus | latest | 30090 | ✅ |
| Grafana | latest | 30000 | ✅ |
| Loki + Promtail | latest | - | ✅ |
| ArgoCD | 2.13.2 | 30080 | ✅ |
| Sealed Secrets | 0.27.2 | - | ✅ |
| Cert-Manager | 1.16.2 | - | ✅ |

### Pod 배포 검증

```powershell
# Master 노드에 배포된 Pod 확인
kubectl get pods -A -o wide | Select-String "k8s-master"

# Worker 노드에 배포된 Pod 확인
kubectl get pods -A -o wide | Select-String "k8s-worker"
```

**기대 결과:**
- ✅ 두 노드 모두 Pod 실행 중
- ✅ Master에도 일반 애플리케이션 Pod 배포 가능

---

## 🧪 **테스트 애플리케이션 배포**

### Nginx 테스트 배포

```powershell
# Deployment 생성
kubectl create deployment nginx --image=nginx --replicas=3

# Service 생성 (NodePort)
kubectl expose deployment nginx --port=80 --type=NodePort

# NodePort 확인
kubectl get svc nginx

# 접속 테스트
$nodePort = (kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')
Start-Process "http://150.230.45.123:$nodePort"
```

### Pod 분산 확인

```powershell
kubectl get pods -o wide | Select-String "nginx"
```

**기대 결과:**
```
nginx-xxx   1/1   Running   k8s-master
nginx-xxx   1/1   Running   k8s-worker
nginx-xxx   1/1   Running   k8s-master
```
✅ **Master와 Worker에 고르게 분산**

---

## 🔧 **문제 해결**

### Terraform 실패 시

```powershell
# 로그 확인
terraform apply -auto-approve

# 특정 리소스만 재생성
terraform taint oci_core_instance.k8s_master[0]
terraform apply

# 완전 재시작
terraform destroy -auto-approve
terraform apply -auto-approve
```

### Ansible 실패 시

```powershell
# Verbose 모드로 재실행
ansible-playbook playbooks\00-deploy-all.yml -i inventory\hosts.ini -vvv

# 특정 단계만 재실행
ansible-playbook playbooks\03-init-cluster.yml -i inventory\hosts.ini

# SSH 직접 연결 확인
ssh ubuntu@150.230.45.123
```

### 클러스터 초기화 (재시작)

```powershell
# Master 노드에서
ssh ubuntu@150.230.45.123
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube

# Worker 노드에서
ssh ubuntu@140.238.78.234
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet

# Ansible 재실행
ansible-playbook playbooks\03-init-cluster.yml -i inventory\hosts.ini
```

---

## 🧹 **전체 삭제**

```powershell
cd c:\Users\taeku\Documents\GitHub\oci-k8s-production\terraform
terraform destroy -auto-approve

# 확인
# - 모든 인스턴스 삭제
# - Reserved IP 해제
# - Block Volume 삭제
# - VCN 및 네트워크 삭제
```

---

## 📌 **다음 단계**

1. **GitOps 설정**: ArgoCD로 애플리케이션 배포
2. **도메인 연결**: DNS A 레코드 → Master IP
3. **TLS 인증서**: Cert-Manager + Let's Encrypt
4. **모니터링 알림**: Prometheus AlertManager
5. **Grafana 대시보드**: Kubernetes 클러스터 모니터링 대시보드 추가
