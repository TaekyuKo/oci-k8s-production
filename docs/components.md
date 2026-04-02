# 컴포넌트 상세 설명

## 📦 핵심 컴포넌트

### 1. Cilium (CNI)

**선택 이유:**
- eBPF 기반으로 커널 수준에서 동작 (고성능)
- NetworkPolicy 완벽 지원
- Hubble을 통한 네트워크 관측성
- Service Mesh 기능 포함 (선택적)

**버전:** v1.19.1 (chart 1.19.1)

**설치 방법:**
```bash
ansible-playbook playbooks/site.yml  # Cilium은 자동 포함
```

**확인:**
```bash
kubectl get pods -n kube-system -l k8s-app=cilium
cilium status
```

---

### 2. Kubernetes Gateway API

**선택 이유:**
- Kubernetes 공식 표준 (Ingress 후속)
- 멀티 벤더 지원 (Nginx, Envoy, Istio 등)
- 더 풍부한 라우팅 기능
- Role 기반 접근 제어

**vs Nginx Ingress:**
| 특징 | Gateway API | Nginx Ingress |
|------|-------------|---------------|
| 표준화 | ✅ K8s 표준 | ❌ 사실상 표준 |
| 확장성 | ✅ 우수 | ⚠️ 제한적 |
| 멀티 테넌트 | ✅ 네이티브 지원 | ⚠️ 복잡 |
| 학습 곡선 | ⚠️ 약간 높음 | ✅ 낮음 |

**설치:**
```bash
ansible-playbook playbooks/site.yml  # Gateway API는 자동 포함
```

---

### 3. Longhorn (분산 스토리지)

**버전:** v1.7.2 (chart 1.7.2)

**Longhorn 선택 이유 (vs Rook-Ceph):**

이 프로젝트는 초기에 Rook-Ceph로 구축되었으나, 2노드 환경에서 Longhorn으로 전환했습니다.

**아키텍처 관점:**
- **Rook-Ceph**: 최소 3개 OSD (Object Storage Daemon) 필요
  - Ceph의 CRUSH 알고리즘은 데이터 복제를 위해 최소 3개 노드 권장
  - 2노드 환경에서는 `mon_allow_pool_size_one=true` 등 비정상적인 설정 필요
  - Quorum 구성이 불안정 (split-brain 위험)
  
- **Longhorn**: 2노드 환경에 최적화
  - 단순한 복제 메커니즘 (replica count 설정 가능)
  - 2노드에서도 안정적인 replica=1 운영 가능
  - 노드 장애 시 자동 재스케줄링

**기술적 차이:**
| 특징 | Longhorn | Rook-Ceph |
|------|----------|-----------|
| 최소 노드 수 | 1개 | 3개 (권장) |
| 설치 복잡도 | ✅ 간단 | ❌ 복잡 (OSD, MON, MGR) |
| 리소스 사용 | ✅ 경량 (~500MB) | ❌ 무거움 (~2GB+) |
| 소규모 클러스터 | ✅ 최적화됨 | ⚠️ 오버스펙 |
| UI | ✅ 내장 | ⚠️ 별도 설치 |
| 백업/복구 | ✅ 내장 | ✅ 지원 |
| 스냅샷 | ✅ 지원 | ✅ 지원 |

**결론:** OCI Free Tier의 2노드 환경에서는 Longhorn이 아키텍처적으로 더 적합합니다.

**StorageClass:**
- `longhorn` (default): 복제본 1개, 동적 프로비저닝
- `longhorn-static`: 정적 프로비저닝용

**접속:**
```bash
# Longhorn UI: http://<master-ip>:30088
```

---

### 4. Prometheus + Grafana

**버전:** kube-prometheus-stack chart 79.9.0 (Prometheus Operator v0.86.2)

**Prometheus:**
- 시계열 데이터베이스
- Pull 방식 메트릭 수집
- PromQL 쿼리 언어
- AlertManager 연동

**Grafana:**
- 시각화 대시보드
- 다양한 데이터 소스 지원
- 알림 기능

**기본 대시보드:**
- Kubernetes Cluster Monitoring
- Node Exporter Full
- Cilium Metrics

**접속:**
```bash
# Grafana: http://<master-ip>:30000
# Prometheus: http://<master-ip>:30090
```

---

### 5. Loki + Promtail

**버전:** loki-stack chart 2.10.3 (Loki v2.9.3)

**선택 이유 (vs EFK Stack):**
| 특징 | Loki | Elasticsearch |
|------|------|---------------|
| 리소스 | ✅ 경량 (500MB~) | ❌ 무거움 (2GB+) |
| 스토리지 | ✅ 저렴 | ❌ 비쌈 |
| 설정 | ✅ 간단 | ❌ 복잡 |
| 검색 | ⚠️ 기본적 | ✅ 강력 |
| Grafana 통합 | ✅ 네이티브 | ⚠️ 플러그인 |

**구성:**
- **Loki**: 로그 수집 및 저장
- **Promtail**: 각 노드에서 로그 전송

**사용:**
```bash
# Grafana에서 Loki 데이터 소스로 로그 확인
# LogQL로 쿼리: {namespace="default"}
```

---

### 6. ArgoCD

**버전:** v2.13.2

**GitOps 워크플로우:**
```
Git Repository (Source of Truth)
         ↓
    ArgoCD (감시)
         ↓
Kubernetes Cluster (자동 배포)
```

**주요 기능:**
- Git을 통한 선언적 배포
- 자동 동기화
- 롤백 지원
- Multi-cluster 관리

**초기 접속:**
```bash
# 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# 접속: https://<master-ip>:30080
# ID: admin
```

---

### 7. Sealed Secrets

**버전:** chart 2.17.9 (app 0.33.1)

**문제:**
- Kubernetes Secret은 base64 인코딩 (암호화 아님)
- Git에 Secret을 올릴 수 없음

**해결:**
- Sealed Secret: 공개키로 암호화
- Git에 안전하게 저장 가능
- 클러스터에서만 복호화 가능

**사용 예시:**
```bash
# Secret 생성
kubectl create secret generic mysecret --dry-run=client \
  --from-literal=password=mysecretpassword -o yaml | \
  kubeseal -o yaml > mysealedsecret.yaml

# Git에 커밋
git add mysealedsecret.yaml
git commit -m "Add sealed secret"

# ArgoCD가 자동 배포 → 클러스터에서 복호화
```

---

### 8. Cert-Manager

**버전:** v1.16.2

**자동화:**
1. Let's Encrypt에 인증서 요청
2. HTTP-01 또는 DNS-01 챌린지 수행
3. 인증서 발급 및 저장
4. 만료 전 자동 갱신

**설정 예시:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: gateway
```

---

### 9. Helm

**역할:**
- Kubernetes 패키지 매니저
- Chart를 통한 애플리케이션 배포
- 버전 관리 및 롤백

**사용 예시:**
```bash
# Chart 설치
helm install myapp stable/nginx

# 업그레이드
helm upgrade myapp stable/nginx --set replicaCount=3

# 롤백
helm rollback myapp 1
```

---

## 🔄 컴포넌트 간 통합

```
┌─────────────────────────────────────────────┐
│              Git Repository                 │
│         (Manifests, Helm Charts)            │
└───────────────┬─────────────────────────────┘
                │
                ↓ (GitOps)
┌─────────────────────────────────────────────┐
│              ArgoCD                         │
│      (자동 배포 및 동기화)                    │
└───────────────┬─────────────────────────────┘
                │
                ↓
┌─────────────────────────────────────────────┐
│         Kubernetes Cluster                  │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  Cilium  │  │ Gateway  │  │   Apps   │ │
│  │   (CNI)  │  │   API    │  │          │ │
│  └──────────┘  └──────────┘  └──────────┘ │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │         Monitoring Layer             │  │
│  │  Prometheus → Grafana (Metrics)      │  │
│  │  Loki → Grafana (Logs)               │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │      Security & Automation           │  │
│  │  Sealed Secrets (암호화)              │  │
│  │  Cert-Manager (SSL 자동화)            │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## 📊 리소스 사용량

| 컴포넌트 | CPU | Memory | 비고 |
|---------|-----|--------|------|
| Cilium | 200m | 500MB | CNI |
| Prometheus | 500m | 2GB | 메트릭 저장 |
| Grafana | 100m | 200MB | 대시보드 |
| Loki | 200m | 500MB | 로그 저장 |
| Promtail | 100m | 128MB | 각 노드 |
| ArgoCD | 500m | 1GB | GitOps |
| Sealed Secrets | 50m | 64MB | 경량 |
| Cert-Manager | 100m | 128MB | 인증서 |
| Gateway API | 200m | 256MB | Ingress |

**총합:** ~3-4GB 메모리 사용 (노드당)

**권장 사양:** Master 12GB, Worker 12GB (프리티어 최대)
