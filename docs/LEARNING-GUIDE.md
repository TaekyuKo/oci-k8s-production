# Kubernetes 학습 가이드 (CICD & 사이드 프로젝트용)

## 🎯 **이 클러스터로 할 수 있는 것**

### ✅ **1. CI/CD 파이프라인 구축**

#### **GitHub → ArgoCD 자동 배포**

```yaml
# example-app.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: my-app
spec:
  type: NodePort
  ports:
  - port: 80
    nodePort: 30100
  selector:
    app: my-app
```

**ArgoCD Application 생성:**
```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-username/your-repo
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**워크플로우:**
1. GitHub에 코드 푸시 → ArgoCD가 자동 감지
2. ArgoCD가 변경사항 자동 배포
3. Grafana에서 배포 후 메트릭 확인
4. Loki에서 애플리케이션 로그 확인

---

### ✅ **2. 모니터링 학습**

#### **Prometheus로 메트릭 수집**

```powershell
# Prometheus UI 접속
Start-Process "http://<master-ip>:30090"

# PromQL 쿼리 연습
# - CPU 사용률: rate(container_cpu_usage_seconds_total[5m])
# - 메모리 사용률: container_memory_usage_bytes
# - Pod 개수: kube_pod_info
```

#### **Grafana 대시보드**

```powershell
# Grafana 접속
Start-Process "http://<master-ip>:30000"

# 추천 대시보드 Import:
# - Kubernetes Cluster Monitoring (ID: 7249)
# - Node Exporter Full (ID: 1860)
# - ArgoCD (ID: 14584)
```

**실습 예시:**
1. 애플리케이션 배포 후 CPU/Memory 사용량 변화 관찰
2. HPA (Horizontal Pod Autoscaler) 테스트
3. 알림 규칙 설정 (CPU > 80% 시 알림)

---

### ✅ **3. 로깅 학습**

#### **Loki로 중앙화된 로그 관리**

```powershell
# Grafana에서 Loki 데이터소스 확인
# Explore > Loki 선택

# LogQL 쿼리 연습
# - 특정 Pod 로그: {pod="my-app-xxx"}
# - 에러 로그만: {pod="my-app-xxx"} |= "error"
# - 시간대별 로그: {namespace="my-app"} | json | line_format "{{.message}}"
```

**실습 예시:**
1. 애플리케이션 에러 발생 시 로그 추적
2. 특정 시간대 로그 필터링
3. 로그 기반 알림 설정

---

### ✅ **4. Secret 관리 학습**

#### **Sealed Secrets로 안전한 Secret 관리**

```powershell
# kubeseal CLI 설치 확인
ssh ubuntu@<master-ip>
kubeseal --version

# Secret 암호화
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Git에 안전하게 커밋
git add sealed-secret.yaml
git commit -m "Add encrypted secret"
git push

# ArgoCD가 자동으로 배포 → Sealed Secrets Controller가 복호화
```

**학습 포인트:**
- Git에 Secret을 안전하게 저장하는 방법
- GitOps 워크플로우에서 Secret 관리

---

### ✅ **5. 네트워킹 학습**

#### **Cilium Hubble로 네트워크 플로우 시각화**

```powershell
# Hubble UI 활성화 (선택)
ssh ubuntu@<master-ip>
kubectl port-forward -n kube-system svc/hubble-ui 8080:80

# 로컬에서 접속
Start-Process "http://localhost:8080"
```

#### **Gateway API로 라우팅 설정**

```yaml
# gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /app
    backendRefs:
    - name: my-app
      port: 80
```

**학습 포인트:**
- Nginx Ingress 대비 Gateway API 장점
- L7 라우팅, 트래픽 분할 (Canary Deployment)

---

### ✅ **6. 리소스 관리 학습**

#### **Metrics Server로 리소스 모니터링**

```powershell
# 노드 리소스 사용량
kubectl top nodes

# Pod 리소스 사용량
kubectl top pods -A

# 특정 네임스페이스
kubectl top pods -n my-app
```

#### **Horizontal Pod Autoscaler (HPA)**

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
  namespace: my-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

**부하 테스트:**
```powershell
# Apache Bench로 부하 생성
kubectl run -it --rm load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://my-app.my-app.svc.cluster.local; done"

# HPA 상태 확인
kubectl get hpa -n my-app -w
```

---

## 🏗️ **사이드 프로젝트 배포 예시**

### **예시 1: FastAPI 백엔드 + React 프론트엔드**

#### **1. 디렉토리 구조**
```
my-project/
├── backend/
│   ├── Dockerfile
│   └── app/
├── frontend/
│   ├── Dockerfile
│   └── src/
└── k8s/
    ├── namespace.yaml
    ├── backend-deployment.yaml
    ├── frontend-deployment.yaml
    ├── ingress.yaml
    └── argocd-app.yaml
```

#### **2. Kubernetes 매니페스트**

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-project
---
# k8s/backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: my-project
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: your-dockerhub/backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: my-project
spec:
  selector:
    app: backend
  ports:
  - port: 8000
```

#### **3. ArgoCD로 자동 배포**

```yaml
# k8s/argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-project
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-username/my-project
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: my-project
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

---

### **예시 2: WordPress + MySQL**

```yaml
# wordpress-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: wordpress
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: wordpress
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
```

---

## 📚 **추천 학습 경로**

### **Week 1-2: 기본 배포 익히기**
- [ ] kubectl 기본 명령어 마스터
- [ ] Deployment, Service, ConfigMap 이해
- [ ] kubectl top으로 리소스 모니터링
- [ ] 간단한 Nginx 앱 배포

### **Week 3-4: CI/CD 구축**
- [ ] ArgoCD에 첫 애플리케이션 연결
- [ ] GitHub → ArgoCD 자동 배포 설정
- [ ] Sealed Secrets로 Secret 관리
- [ ] 배포 후 Grafana에서 메트릭 확인

### **Week 5-6: 모니터링 & 로깅**
- [ ] Prometheus PromQL 쿼리 학습
- [ ] Grafana 커스텀 대시보드 생성
- [ ] Loki LogQL 쿼리 학습
- [ ] 애플리케이션 로그 추적

### **Week 7-8: 고급 기능**
- [ ] HPA로 자동 스케일링
- [ ] Gateway API로 트래픽 라우팅
- [ ] Cert-Manager로 TLS 인증서 발급
- [ ] Cilium Hubble로 네트워크 플로우 확인

### **Week 9+: 사이드 프로젝트 배포**
- [ ] 자신의 애플리케이션 컨테이너화
- [ ] Kubernetes 매니페스트 작성
- [ ] ArgoCD로 GitOps 워크플로우 구축
- [ ] 프로덕션급 모니터링 설정

---

## 🎓 **학습 리소스**

### **공식 문서**
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [ArgoCD 가이드](https://argo-cd.readthedocs.io/)
- [Prometheus 쿼리 가이드](https://prometheus.io/docs/prometheus/latest/querying/basics/)

### **실습 자료**
- [Kubernetes by Example](https://kubernetesbyexample.com/)
- [Play with Kubernetes](https://labs.play-with-k8s.com/)

### **추천 강의**
- [Udemy] Certified Kubernetes Administrator (CKA)
- [Coursera] Google Kubernetes Engine 전문가 과정

---

## 💡 **팁**

### **1. 비용 절감**
- Prometheus retention을 7일로 유지
- Loki retention을 3일로 유지
- 불필요한 Pod 리소스 요청/제한 설정

### **2. 학습 효율**
- 하루에 하나씩 새로운 개념 학습
- 실습 위주로 진행 (이론 30%, 실습 70%)
- Grafana 대시보드를 항상 켜두고 변화 관찰

### **3. 실전 경험**
- 실제 사이드 프로젝트를 배포해보기
- GitHub Actions → ArgoCD 연동해보기
- 장애 상황 시뮬레이션 (Pod 삭제 후 복구 과정 관찰)

---

## 🚀 **다음 단계 (선택)**

현재 구성으로 충분하지만, 더 깊이 학습하려면:

### **추가 고려사항**
- **Istio/Linkerd**: Service Mesh 학습 (고급)
- **Velero**: 백업/복구 학습
- **Kyverno**: Policy as Code
- **Tekton**: Kubernetes-native CI/CD

하지만 **현재 구성만으로도 CICD, 모니터링, 사이드 프로젝트 배포 학습에는 완벽합니다!**
