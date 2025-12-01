# OCI Kubernetes Production 배포 실행 가이드

## 🚀 **전체 배포 프로세스 (30-40분)**

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: 사전 준비 (5분)                                    │
│  └─> OCI 계정 정보 + SSH 키 준비                            │
├─────────────────────────────────────────────────────────────┤
│  Phase 2: Terraform 인프라 구축 (5-10분)                    │
│  └─> VCN, Instances, IPs, Volumes 생성                      │
├─────────────────────────────────────────────────────────────┤
│  Phase 3: Ansible 클러스터 구성 (20-30분)                   │
│  └─> Kubernetes 설치 + Addon 배포                           │
├─────────────────────────────────────────────────────────────┤
│  Phase 4: 검증 및 접속 (5분)                                │
│  └─> kubectl 설정 + 웹 UI 확인                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 **Phase 1: 사전 준비 (5분)**

### **Step 1.1: 필수 도구 설치 확인**

```powershell
# Terraform 버전 확인 (1.0 이상 필요)
terraform version

# Ansible 버전 확인 (2.14 이상 필요)
ansible --version

# 미설치 시
# Terraform: https://www.terraform.io/downloads
# Ansible: pip install ansible
```

### **Step 1.2: OCI 계정 정보 준비**

필요한 정보를 메모장에 정리하세요:

```
✅ Tenancy OCID: ocid1.tenancy.oc1..aaaaaaaXXXXXX
✅ User OCID: ocid1.user.oc1..aaaaaaaXXXXXX
✅ API Key Fingerprint: aa:bb:cc:dd:ee:ff:...
✅ API Private Key 경로: C:\Users\taeku\.oci\oci_api_key.pem
✅ Region: ap-chuncheon-1
✅ Compartment OCID: ocid1.compartment.oc1..aaaaaaaXXXXXX
```

**OCI 콘솔에서 확인 방법:**
```
Tenancy OCID: Profile → Tenancy → OCID 복사
User OCID: Profile → User Settings → OCID 복사
Fingerprint: Profile → API Keys → Fingerprint
Compartment OCID: Identity → Compartments → 원하는 Compartment 선택 → OCID 복사
```

### **Step 1.3: SSH 키 준비**

```powershell
# SSH 키 생성 (없는 경우)
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa

# 공개키 확인
cat $env:USERPROFILE\.ssh\id_rsa.pub

# 출력 예시:
# ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... taeku@DESKTOP-XXX
```

---

## 🏗️ **Phase 2: Terraform 인프라 구축 (5-10분)**

### **Step 2.1: 프로젝트 디렉토리 이동**

```powershell
cd c:\Users\taeku\Documents\GitHub\oci-k8s-production\terraform
```

### **Step 2.2: terraform.tfvars 파일 생성**

```powershell
# 예제 파일 복사
Copy-Item terraform.tfvars.example terraform.tfvars

# 편집기로 열기
notepad terraform.tfvars
```

**terraform.tfvars 내용 입력:**
```hcl
# ========================================
# OCI 인증 정보 (필수)
# ========================================
tenancy_ocid       = "ocid1.tenancy.oc1..aaaaaaaXXXXXX"
user_ocid          = "ocid1.user.oc1..aaaaaaaXXXXXX"
fingerprint        = "aa:bb:cc:dd:ee:ff:11:22:33:44:55:66:77:88:99:00"
private_key_path   = "C:/Users/taeku/.oci/oci_api_key.pem"
region             = "ap-chuncheon-1"

# ========================================
# 리소스 위치 (필수)
# ========================================
compartment_ocid   = "ocid1.compartment.oc1..aaaaaaaXXXXXX"

# ========================================
# SSH 접속 키 (필수)
# ========================================
ssh_public_key     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... taeku@DESKTOP"

# ========================================
# 클러스터 설정 (선택 - 기본값 사용 가능)
# ========================================
cluster_name       = "k8s-prod"
master_count       = 1  # 변경 불가 (Free Tier 제약)
worker_count       = 1  # 변경 불가 (Free Tier 제약)
instance_ocpus     = 2
instance_memory    = 12
boot_volume_size   = 50
block_volume_size  = 50
```

**⚠️ 주의사항:**
- 경로는 슬래시(`/`) 사용 (Windows에서도)
- ssh_public_key는 **전체 내용** 한 줄로 입력
- 따옴표(`"`) 안에 값 입력

### **Step 2.3: Terraform 초기화**

```powershell
terraform init
```

**예상 출력:**
```
Initializing the backend...
Initializing provider plugins...
- Installing hashicorp/oci v5.x.x...
- Installed hashicorp/oci v5.x.x

Terraform has been successfully initialized!
```

### **Step 2.4: 배포 계획 확인**

```powershell
terraform plan
```

**예상 출력 (중요 부분):**
```
Plan: 17 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + master_public_ips    = [
      + (known after apply),
    ]
  + worker_public_ips    = [
      + (known after apply),
    ]
  + primary_master_ip    = (known after apply)
```

**확인 포인트:**
- ✅ `17 to add` (17개 리소스 생성)
- ✅ 에러 메시지 없음
- ✅ Reserved IP 1개만 생성 예정

### **Step 2.5: 인프라 생성 실행**

```powershell
terraform apply
```

**프롬프트:**
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

**입력:**
```
yes
```

**실행 과정 (5-10분):**
```
oci_core_vcn.k8s_vcn: Creating...
oci_core_vcn.k8s_vcn: Creation complete after 2s
oci_core_internet_gateway.k8s_igw: Creating...
oci_core_subnet.public_subnet: Creating...
oci_core_instance.k8s_master[0]: Creating...
oci_core_instance.k8s_worker[0]: Creating...
oci_core_instance.k8s_master[0]: Still creating... [10s elapsed]
oci_core_instance.k8s_master[0]: Still creating... [20s elapsed]
...
oci_core_instance.k8s_master[0]: Creation complete after 3m12s
oci_core_public_ip.master_ip[0]: Creating...
oci_core_volume.master_bv[0]: Creating...
...
Apply complete! Resources: 17 added, 0 changed, 0 destroyed.

Outputs:

master_public_ips = [
  "150.230.45.123",
]
worker_public_ips = [
  "140.238.67.234",
]
primary_master_ip = "150.230.45.123"
ssh_connection_commands = <<EOT
# Master nodes (Reserved IPs)
ssh ubuntu@150.230.45.123  # k8s-master

# Worker nodes (Ephemeral IPs)
ssh ubuntu@140.238.67.234  # k8s-worker
EOT
```

### **Step 2.6: IP 주소 저장**

```powershell
# Master IP 저장
$MASTER_IP = terraform output -raw primary_master_ip
echo "Master IP: $MASTER_IP"

# 메모장에 기록
# Master IP: 150.230.45.123
# Worker IP: 140.238.67.234
```

### **Step 2.7: Ansible Inventory 자동 생성 확인**

```powershell
cat ..\ansible\inventory\hosts.ini
```

**예상 출력:**
```ini
[k8s_master]
k8s-master ansible_host=150.230.45.123 ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[k8s_workers]
k8s-worker ansible_host=140.238.67.234 ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[k8s_all:children]
k8s_master
k8s_workers

[k8s_all:vars]
ansible_python_interpreter=/usr/bin/python3
```

✅ **Terraform 완료!** 인프라가 준비되었습니다.

---

## 🔧 **Phase 3: Ansible 클러스터 구성 (20-30분)**

### **Step 3.1: Ansible 디렉토리 이동**

```powershell
cd ..\ansible
```

### **Step 3.2: 인스턴스 준비 대기 (중요!)**

```powershell
# 인스턴스가 완전히 부팅될 때까지 대기 (1-2분)
Start-Sleep -Seconds 90

# SSH 연결 테스트
ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "echo 'Master node ready'"
```

**예상 출력:**
```
Master node ready
```

**연결 실패 시:**
```powershell
# 30초 더 대기 후 재시도
Start-Sleep -Seconds 30
ssh ubuntu@$MASTER_IP "echo 'Ready'"
```

### **Step 3.3: Ansible 연결 테스트**

```powershell
ansible all -i inventory\hosts.ini -m ping
```

**예상 출력:**
```
k8s-master | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
k8s-worker | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

**⚠️ 연결 실패 시 해결:**
```powershell
# SSH 키 권한 확인 (Windows)
icacls $env:USERPROFILE\.ssh\id_rsa

# 권한 재설정
icacls $env:USERPROFILE\.ssh\id_rsa /inheritance:r
icacls $env:USERPROFILE\.ssh\id_rsa /grant:r "$($env:USERNAME):(R)"
```

### **Step 3.4: 전체 자동 배포 실행**

```powershell
ansible-playbook playbooks\00-deploy-all.yml -i inventory\hosts.ini
```

**실행 과정 (20-30분):**

```
PLAY [=== Stage 1: Prepare All Nodes ===] ************************************

TASK [common : Wait for APT lock to be released] *****************************
ok: [k8s-master]
ok: [k8s-worker]

TASK [common : Update apt cache] *********************************************
changed: [k8s-master]
changed: [k8s-worker]

TASK [common : Remove OCI default REJECT rules from INPUT chain] *************
changed: [k8s-master]
changed: [k8s-worker]

TASK [containerd : Install containerd] ***************************************
changed: [k8s-master]
changed: [k8s-worker]

... (많은 출력) ...

PLAY [=== Stage 2: Install Kubernetes ===] ***********************************

TASK [kubernetes : Install Kubernetes components] ****************************
changed: [k8s-master]
changed: [k8s-worker]

PLAY [=== Stage 3: Initialize Cluster ===] ***********************************

TASK [k8s-master : Initialize Kubernetes master] *****************************
changed: [k8s-master]

TASK [k8s-master : Remove master node taint] *********************************
changed: [k8s-master]

TASK [k8s-worker : Join worker node to cluster] ******************************
changed: [k8s-worker]

TASK [k8s-worker : Label worker node with worker role] ***********************
changed: [k8s-worker]

PLAY [=== Stage 4: Install Cilium CNI ===] ***********************************

TASK [cilium : Install Cilium CNI] *******************************************
changed: [k8s-master]

... (계속) ...

PLAY [=== Stage 7: Install Monitoring (Prometheus + Grafana) ===] ************

TASK [monitoring : Install kube-prometheus-stack] ****************************
changed: [k8s-master]

PLAY [=== Stage 9: Install ArgoCD ===] ***************************************

TASK [argocd : Install ArgoCD] ***********************************************
changed: [k8s-master]

... (계속) ...

PLAY [=== Deployment Complete ===] *******************************************

TASK [Display completion message] ********************************************
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
        "",
        "  3. Access Grafana:",
        "     http://150.230.45.123:30000",
        "",
        "========================================="
    ]
}

PLAY RECAP ********************************************************************
k8s-master                 : ok=87   changed=54   unreachable=0    failed=0
k8s-worker                 : ok=43   changed=28   unreachable=0    failed=0
localhost                  : ok=1    changed=0    unreachable=0    failed=0
```

✅ **Ansible 완료!** Kubernetes 클러스터가 준비되었습니다.

---

## ✅ **Phase 4: 검증 및 접속 (5분)**

### **Step 4.1: kubeconfig 가져오기**

```powershell
# .kube 디렉토리 생성 (없는 경우)
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\.kube

# Master 노드에서 kubeconfig 복사
scp ubuntu@${MASTER_IP}:/home/ubuntu/.kube/config $env:USERPROFILE\.kube\config
```

### **Step 4.2: 클러스터 상태 확인**

```powershell
# 노드 확인
kubectl get nodes
```

**기대 결과:**
```
NAME         STATUS   ROLES           AGE   VERSION
k8s-master   Ready    control-plane   15m   v1.31.4
k8s-worker   Ready    worker          13m   v1.31.4
```

**확인 포인트:**
- ✅ 두 노드 모두 `Ready` 상태
- ✅ k8s-master: `control-plane` 역할
- ✅ k8s-worker: `worker` 역할

```powershell
# Pod 상태 확인
kubectl get pods -A
```

**기대 결과 (약 40-50개 Pod):**
```
NAMESPACE      NAME                                       READY   STATUS    RESTARTS   AGE
argocd         argocd-application-controller-xxx          1/1     Running   0          5m
argocd         argocd-server-xxx                          1/1     Running   0          5m
cert-manager   cert-manager-xxx                           1/1     Running   0          3m
kube-system    cilium-xxx                                 1/1     Running   0          12m
kube-system    cilium-operator-xxx                        1/1     Running   0          12m
kube-system    coredns-xxx                                1/1     Running   0          15m
monitoring     prometheus-grafana-xxx                     2/2     Running   0          7m
...
```

### **Step 4.3: Master Taint 제거 확인**

```powershell
kubectl describe node k8s-master | Select-String "Taints"
```

**기대 결과:**
```
Taints:             <none>
```
✅ Taint가 없어야 정상 (Pod 스케줄링 가능)

### **Step 4.4: 리소스 사용량 확인**

```powershell
kubectl top nodes
```

**기대 결과:**
```
NAME         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
k8s-master   521m         26%    4215Mi          35%
k8s-worker   312m         15%    2834Mi          23%
```

### **Step 4.5: 웹 UI 접속**

#### **Grafana 접속**

```powershell
# Grafana 비밀번호 확인
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# 출력 예시: prom-operator

# 브라우저 열기
Start-Process "http://${MASTER_IP}:30000"
```

**로그인:**
- URL: `http://150.230.45.123:30000`
- ID: `admin`
- PW: `(위에서 확인한 비밀번호)`

#### **ArgoCD 접속**

```powershell
# ArgoCD 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# 출력 예시: Xk7pQ9vR2mN5

# 브라우저 열기
Start-Process "https://${MASTER_IP}:30080"
```

**로그인:**
- URL: `https://150.230.45.123:30080`
- ID: `admin`
- PW: `(위에서 확인한 비밀번호)`

**⚠️ 인증서 경고:** "고급" → "계속하기" 클릭 (자체 서명 인증서)

---

## 🎉 **배포 완료!**

### **최종 체크리스트**

- [x] Terraform으로 인프라 생성 완료
- [x] Ansible로 Kubernetes 클러스터 구성 완료
- [x] kubectl로 노드 상태 확인 (`Ready`)
- [x] Master taint 제거 확인 (`<none>`)
- [x] Worker role 라벨 확인
- [x] 모든 Pod Running 상태
- [x] Grafana 접속 성공
- [x] ArgoCD 접속 성공

---

## 🔧 **문제 해결**

### **Terraform 실패 시**

```powershell
# 상세 로그 확인
$env:TF_LOG="DEBUG"
terraform apply

# 특정 리소스 재생성
terraform taint oci_core_instance.k8s_master[0]
terraform apply

# 완전 재시작
terraform destroy -auto-approve
terraform apply -auto-approve
```

### **Ansible 실패 시**

```powershell
# Verbose 모드로 재실행
ansible-playbook playbooks\00-deploy-all.yml -i inventory\hosts.ini -vvv

# 특정 단계만 재실행
ansible-playbook playbooks\01-prepare-nodes.yml -i inventory\hosts.ini
ansible-playbook playbooks\03-init-cluster.yml -i inventory\hosts.ini

# SSH 직접 확인
ssh ubuntu@$MASTER_IP
sudo systemctl status kubelet
```

### **kubectl 연결 실패 시**

```powershell
# kubeconfig 재다운로드
Remove-Item $env:USERPROFILE\.kube\config
scp ubuntu@${MASTER_IP}:/home/ubuntu/.kube/config $env:USERPROFILE\.kube\config

# 권한 확인
kubectl cluster-info
```

---

## 🧹 **전체 삭제**

```powershell
cd c:\Users\taeku\Documents\GitHub\oci-k8s-production\terraform
terraform destroy -auto-approve
```

**삭제 확인:**
- 모든 인스턴스 삭제
- Reserved IP 해제
- Block Volume 삭제
- VCN 및 네트워크 삭제

---

## 📝 **다음 단계**

1. **사이드 프로젝트 배포**: `docs/LEARNING-GUIDE.md` 참고
2. **모니터링 학습**: Grafana 대시보드 커스터마이징
3. **GitOps 실습**: ArgoCD로 애플리케이션 배포
4. **로깅 확인**: Loki에서 로그 쿼리 연습

축하합니다! 🎉 프로덕션급 Kubernetes 클러스터가 준비되었습니다.
