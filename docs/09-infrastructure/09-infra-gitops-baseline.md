# Manifesto 6 — **Infra/GitOps Baseline**

*(Helm + Kustomize + ArgoCD "app-of-apps" + Istio/Linkerd + External Secrets + Policies + Autoscaling + Backup/DR + FinOps)*

Este manifesto de infraestrutura foi **integrado com os padrões técnicos** definidos no plano de ação do monorepo, garantindo alinhamento entre arquitetura, desenvolvimento e operações. Estabelece **padrões de cluster**, **segurança**, **rede**, **segredos**, **observabilidade**, **autoscaling**, **quotas**, **backup/DR** e **custos** — coerente com os Manifestos 1–5.

## 🏗️ Integração com Padrões de Infraestrutura do Monorepo

### Stack de Infraestrutura Integrada
- **Orquestração**: Kubernetes com Helm + Kustomize + ArgoCD
- **Service Mesh**: Istio/Linkerd com mTLS e políticas de rede
- **Segredos**: External Secrets com AWS Secrets Manager/GCP SM
- **Observabilidade**: OpenTelemetry → Tempo/Jaeger + Prometheus + Loki
- **CI/CD**: GitHub Actions com GitOps e validação de infraestrutura

### Padrões de Infraestrutura Aplicados
- **IaC**: Helm charts padronizados com valores por ambiente
- **GitOps**: ArgoCD com app-of-apps pattern
- **Segurança**: Pod Security Standards, Network Policies, RBAC
- **FinOps**: Labels de custo, quotas, autoscaling baseado em métricas

---

## 📁 Estrutura de diretórios (monorepo IaC)

```
infra/
  README.md
  clusters/
    prod/
      kustomization.yaml
      apps/
        argocd/
          kustomization.yaml
          namespace.yaml
          argo-cm.yaml
          argo-rbac.yaml
        app-of-apps/
          application.yaml
        istio/
          kustomization.yaml
          base.yaml
          peer-authentication.yaml
          mtls-destinationrules.yaml
          ratelimit-envoyfilter.yaml
          authz-policies.yaml
        gateways/
          obraflow-gw.yaml
        namespaces/
          obraflow-app.yaml
          obraflow-data.yaml
          observability.yaml
        policies/
          pod-security.yaml
          network-default-deny.yaml
          resource-quotas.yaml
          limit-range.yaml
          gatekeeper-constraints.yaml
        storage/
          storageclasses.yaml
          velero/
            namespace.yaml
            values.yaml
        autoscaling/
          karpenter/
            provisioner.yaml
            nodepool-spot.yaml
          hpa/
            work-mgmt-hpa.yaml
            measurement-hpa.yaml
          pdb/
            work-mgmt-pdb.yaml
        externalsecrets/
          es-operator.yaml
          obraflow-app-secrets.yaml
    hml/
      ... (mesma estrutura)
    dev/
      ... (mesma estrutura)
  charts/
    obraflow-service/
      Chart.yaml
      values.yaml
      templates/
        deployment.yaml
        service.yaml
        serviceaccount.yaml
        hpa.yaml
        pdb.yaml
        networkpolicy.yaml
        virtualservice.yaml
        destinationrule.yaml
        servicemonitor.yaml
  argo-apps/
    obraflow-services.yaml
    observability-stack.yaml
    data-plane.yaml
  scripts/
    bootstrap-argocd.sh
    validate.sh
  .github/workflows/
    cd-gitops.yml
```

---

## 1) **README.md** (uso resumido)

* **Fluxo:** PR → merge em `main` → ArgoCD reconcilia → cluster converge.
* **Padrões:** **mTLS** no mesh, **NetworkPolicy default-deny**, **PodSecurity** `restricted`, **External Secrets**, **Storage** encriptado, **HPA/PDB**, **Karpenter** (ou Cluster Autoscaler), **Velero** (backup/DR), **cost labels**.
* **Ambientes:** `dev`, `hml`, `prod` (overlays independentes).

---

## 2) ArgoCD “app-of-apps” (produção)

`clusters/prod/apps/app-of-apps/application.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: obraflow-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/sua-org/obraflow-infra.git
    targetRevision: main
    path: argo-apps
  destination:
    name: ''
    namespace: argocd
    server: https://kubernetes.default.svc
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true, PrunePropagationPolicy=foreground]
```

`argo-apps/obraflow-services.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: obraflow-services, namespace: argocd }
spec:
  source:
    repoURL: https://github.com/sua-org/obraflow-infra.git
    targetRevision: main
    path: charts/obraflow-service
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: obraflow-app
  syncPolicy: { automated: { prune: true, selfHeal: true } }
```

\*(Apps separados para **observability**, **data-plane** (DBs gerenciados/operadores), **mesh** e **externalsecrets**) \*

---

## 3) **Helm chart** padrão de serviço (12-factor + mesh + observabilidade)

`charts/obraflow-service/values.yaml` (trecho chave)

```yaml
nameOverride: work-mgmt
image:
  repository: ghcr.io/sua-org/work-mgmt
  tag: "0.1.0"
  pullPolicy: IfNotPresent

replicaCount: 3
resources:
  requests: { cpu: "200m", memory: "256Mi" }
  limits:   { cpu: "1",   memory: "512Mi" }

env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: http://otel-collector.observability:4318
  - name: DEPLOY_ENV
    valueFrom: { fieldRef: { fieldPath: metadata.annotations['obraflow.io/env'] } }

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: false

mesh:
  istio:
    sidecar: true
    mtls: STRICT
    timeout: 2s
    retries: { attempts: 3, perTryTimeout: 800ms }

hpa:
  enabled: true
  minReplicas: 3
  maxReplicas: 15
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 70 } }
pdb:
  minAvailable: 2

serviceMonitor:
  enabled: true

networkPolicy:
  enabled: true
  egress:
    - toNamespace: observability
    - toNamespace: obraflow-data
```

`templates/deployment.yaml` (trecho com **labels de custo** e **OTel**)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "obraflow-service.fullname" . }}
  labels:
    app.kubernetes.io/name: {{ include "obraflow-service.name" . }}
    obraflow.io/tenant: shared
    obraflow.io/cost-center: "obraflow-app"
    obraflow.io/component: "work-management"
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels: { app: {{ include "obraflow-service.name" . }} }
  template:
    metadata:
      labels:
        app: {{ include "obraflow-service.name" . }}
        sidecar.istio.io/inject: "{{ ternary "true" "false" .Values.mesh.istio.sidecar }}"
        obraflow.io/env: "prod"
      annotations:
        obraflow.io/env: "prod"
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      serviceAccountName: {{ include "obraflow-service.name" . }}
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports: [{ containerPort: 8080 }]
          env: {{- toYaml .Values.env | nindent 10 }}
          readinessProbe: { httpGet: { path: /health, port: 8080 }, initialDelaySeconds: 5, periodSeconds: 10 }
          livenessProbe:  { httpGet: { path: /live,   port: 8080 }, initialDelaySeconds: 10, periodSeconds: 10 }
          resources: {{- toYaml .Values.resources | nindent 12 }}
```

`templates/virtualservice.yaml` (Istio: **timeout/retry/circuit**)

```yaml
{{- if .Values.mesh.istio.sidecar }}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata: { name: {{ include "obraflow-service.name" . }} }
spec:
  hosts: [ "{{ include "obraflow-service.name" . }}" ]
  http:
    - timeout: {{ .Values.mesh.istio.timeout }}
      retries:
        attempts: {{ .Values.mesh.istio.retries.attempts }}
        perTryTimeout: {{ .Values.mesh.istio.retries.perTryTimeout }}
      route:
        - destination:
            host: {{ include "obraflow-service.name" . }}
            subset: v1
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata: { name: {{ include "obraflow-service.name" . }} }
spec:
  host: {{ include "obraflow-service.name" . }}
  trafficPolicy:
    tls: { mode: ISTIO_MUTUAL }
{{- end }}
```

---

## 4) **Mesh** (Istio) — mTLS, Rate-Limit e AuthZ

`clusters/prod/apps/istio/peer-authentication.yaml`

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata: { name: default, namespace: istio-system }
spec:
  mtls: { mode: STRICT }
```

`clusters/prod/apps/istio/authz-policies.yaml`

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata: { name: allow-bff-to-services, namespace: obraflow-app }
spec:
  selector:
    matchLabels: { app: work-mgmt }  # aplique via labelSelector por app
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/obraflow-app/sa/bff"]
```

`clusters/prod/apps/istio/ratelimit-envoyfilter.yaml` (opcional, exemplo simples)

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata: { name: ratelimit-global, namespace: istio-system }
spec:
  configPatches:
    - applyTo: NETWORK_FILTER
      match: { listener: { filterChain: { filter: { name: "envoy.filters.network.http_connection_manager" } } } }
      patch:
        operation: MERGE
        value:
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
            request_headers_to_add:
              - header: { key: "x-ratelimit-tenant", value: "%REQ(X-TENANT-ID)%" }
```

---

## 5) **External Secrets** (AWS Secrets Manager ou GCP SM)

`clusters/prod/externalsecrets/es-operator.yaml`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: { name: obraflow-app-secrets, namespace: obraflow-app }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: cloud-secrets, kind: ClusterSecretStore }
  target:
    name: obraflow-app
    creationPolicy: Owner
  data:
    - secretKey: POSTGRES_URI
      remoteRef: { key: prod/obraflow/pg_uri }
    - secretKey: OIDC_CLIENT_SECRET
      remoteRef: { key: prod/obraflow/oidc_client_secret }
```

*(configure `ClusterSecretStore` com role/SA apropriados; **nunca** versão segredos no repo)*

---

## 6) **Policies de segurança de cluster**

### Pod Security (restricted)

`clusters/prod/policies/pod-security.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: obraflow-app
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/version: v1.30
---
apiVersion: v1
kind: Namespace
metadata:
  name: obraflow-data
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/version: v1.30
---
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/version: v1.30
---
# Pod Security Policy para workloads críticos
apiVersion: policy/v1
kind: PodSecurityPolicy
metadata:
  name: obraflow-restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

### NetworkPolicy default-deny + egress seletivo

`clusters/prod/policies/network-default-deny.yaml`

```yaml
# Default deny all ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-ingress, namespace: obraflow-app }
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
---
# Default deny all egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-egress, namespace: obraflow-app }
spec:
  podSelector: {}
  policyTypes: ["Egress"]
---
# Allow DNS resolution
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-dns, namespace: obraflow-app }
spec:
  podSelector: {}
  egress:
    - to: []
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
---
# Allow BFF to services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-bff-to-services, namespace: obraflow-app }
spec:
  podSelector:
    matchLabels: { app: bff }
  egress:
    - to:
        - podSelector:
            matchLabels: { app: work-mgmt }
      ports:
        - protocol: TCP
          port: 8080
    - to:
        - podSelector:
            matchLabels: { app: measurement }
      ports:
        - protocol: TCP
          port: 8080
---
# Allow services to observability
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-to-observability, namespace: obraflow-app }
spec:
  podSelector: {}
  egress:
    - to:
        - namespaceSelector:
            matchLabels: { name: observability }
      ports:
        - protocol: TCP
          port: 4318  # OTel gRPC
        - protocol: TCP
          port: 4317  # OTel HTTP
        - protocol: TCP
          port: 9090  # Prometheus
---
# Allow services to data plane
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-to-data-plane, namespace: obraflow-app }
spec:
  podSelector: {}
  egress:
    - to:
        - namespaceSelector:
            matchLabels: { name: obraflow-data }
      ports:
        - protocol: TCP
          port: 5432  # PostgreSQL
        - protocol: TCP
          port: 27017 # MongoDB
        - protocol: TCP
          port: 9092  # Kafka
        - protocol: TCP
          port: 6379  # Redis
```

### ResourceQuota + LimitRange

`clusters/prod/policies/resource-quotas.yaml`

```yaml
# ResourceQuota para obraflow-app
apiVersion: v1
kind: ResourceQuota
metadata: { name: rq-obraflow-app, namespace: obraflow-app }
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "100"
    limits.memory: 200Gi
    pods: "300"
    persistentvolumeclaims: "50"
    services: "20"
    secrets: "100"
    configmaps: "100"
---
# ResourceQuota para obraflow-data
apiVersion: v1
kind: ResourceQuota
metadata: { name: rq-obraflow-data, namespace: obraflow-data }
spec:
  hard:
    requests.cpu: "50"
    requests.memory: 100Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    pods: "100"
    persistentvolumeclaims: "20"
    services: "10"
    secrets: "50"
    configmaps: "50"
---
# ResourceQuota para observability
apiVersion: v1
kind: ResourceQuota
metadata: { name: rq-observability, namespace: observability }
spec:
  hard:
    requests.cpu: "30"
    requests.memory: 60Gi
    limits.cpu: "150"
    limits.memory: 300Gi
    pods: "200"
    persistentvolumeclaims: "30"
    services: "15"
    secrets: "30"
    configmaps: "30"
```

`clusters/prod/policies/limit-range.yaml`

```yaml
# LimitRange para obraflow-app
apiVersion: v1
kind: LimitRange
metadata: { name: lr-obraflow-app, namespace: obraflow-app }
spec:
  limits:
    - type: Container
      default: { cpu: "500m", memory: "512Mi" }
      defaultRequest: { cpu: "200m", memory: "256Mi" }
      max: { cpu: "2", memory: "4Gi" }
      min: { cpu: "100m", memory: "128Mi" }
    - type: Pod
      max: { cpu: "4", memory: "8Gi" }
---
# LimitRange para obraflow-data
apiVersion: v1
kind: LimitRange
metadata: { name: lr-obraflow-data, namespace: obraflow-data }
spec:
  limits:
    - type: Container
      default: { cpu: "1", memory: "2Gi" }
      defaultRequest: { cpu: "500m", memory: "1Gi" }
      max: { cpu: "8", memory: "16Gi" }
      min: { cpu: "200m", memory: "256Mi" }
    - type: Pod
      max: { cpu: "16", memory: "32Gi" }
---
# LimitRange para observability
apiVersion: v1
kind: LimitRange
metadata: { name: lr-observability, namespace: observability }
spec:
  limits:
    - type: Container
      default: { cpu: "500m", memory: "1Gi" }
      defaultRequest: { cpu: "200m", memory: "512Mi" }
      max: { cpu: "4", memory: "8Gi" }
      min: { cpu: "100m", memory: "128Mi" }
    - type: Pod
      max: { cpu: "8", memory: "16Gi" }
```

`clusters/prod/policies/gatekeeper-constraints.yaml`

```yaml
# Gatekeeper constraints para reforçar políticas
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        properties:
          labels:
            type: array
            items:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := input.review.object.metadata.labels
          missing := required[_]
          not provided[missing]
          msg := sprintf("Missing required label: %v", [missing])
        }
---
apiVersion: config.gatekeeper.sh/v1alpha1
kind: K8sRequiredLabels
metadata:
  name: obraflow-labels
spec:
  match:
    - apiGroups: ["apps"]
      kinds: ["Deployment", "StatefulSet", "DaemonSet"]
      namespaces: ["obraflow-app", "obraflow-data", "observability"]
  parameters:
    labels: ["app.kubernetes.io/name", "app.kubernetes.io/version", "obraflow.io/component"]
```

---

## 7) **Autoscaling e Confiabilidade**

### HPA por serviço (ex.: Work-Mgmt)

`clusters/prod/autoscaling/hpa/work-mgmt-hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: work-mgmt, namespace: obraflow-app }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: work-mgmt }
  minReplicas: 3
  maxReplicas: 20
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
        - type: Pods
          value: 4
          periodSeconds: 15
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
        - type: Pods
          value: 2
          periodSeconds: 60
      selectPolicy: Min
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 70 } }
    - type: Resource
      resource: { name: memory, target: { type: Utilization, averageUtilization: 80 } }
    - type: Pods
      pods: { metric: { name: http_requests_per_second }, target: { type: AverageValue, averageValue: "100" } }
---
# HPA para BFF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: bff, namespace: obraflow-app }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: bff }
  minReplicas: 2
  maxReplicas: 15
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - type: Percent
          value: 200
          periodSeconds: 15
        - type: Pods
          value: 2
          periodSeconds: 15
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
      selectPolicy: Min
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 60 } }
    - type: Resource
      resource: { name: memory, target: { type: Utilization, averageUtilization: 70 } }
    - type: Pods
      pods: { metric: { name: http_requests_per_second }, target: { type: AverageValue, averageValue: "200" } }
```

### PDB (alta disponibilidade)

`clusters/prod/autoscaling/pdb/work-mgmt-pdb.yaml`

```yaml
# PDB para work-mgmt
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: work-mgmt, namespace: obraflow-app }
spec:
  minAvailable: 2
  selector: { matchLabels: { app: work-mgmt } }
---
# PDB para BFF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: bff, namespace: obraflow-app }
spec:
  minAvailable: 1
  selector: { matchLabels: { app: bff } }
---
# PDB para measurement
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: measurement, namespace: obraflow-app }
spec:
  minAvailable: 2
  selector: { matchLabels: { app: measurement } }
---
# PDB para observability (Prometheus)
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: prometheus, namespace: observability }
spec:
  minAvailable: 1
  selector: { matchLabels: { app: prometheus } }
---
# PDB para data plane (PostgreSQL)
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: postgres, namespace: obraflow-data }
spec:
  minAvailable: 1
  selector: { matchLabels: { app: postgres } }
```

### Karpenter (ou Cluster Autoscaler)

`clusters/prod/autoscaling/karpenter/provisioner.yaml`

```yaml
# NodePool para workloads críticos (on-demand)
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata: { name: critical }
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    expireAfter: 2160h  # 90 dias
  template:
    metadata:
      labels: 
        workload: "critical"
        node-type: "on-demand"
      annotations:
        karpenter.sh/capacity-type: on-demand
    spec:
      requirements:
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["on-demand"]
        - key: "node.kubernetes.io/instance-type"
          operator: In
          values: ["m5.large", "m5.xlarge", "m5.2xlarge", "c5.large", "c5.xlarge"]
      nodeClassRef: { name: default }
      taints:
        - key: "workload"
          value: "critical"
          effect: "NoSchedule"
  limits: { cpu: "500", memory: 2000Gi }
---
# NodePool para workloads tolerantes (spot)
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata: { name: spot }
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    expireAfter: 2160h  # 90 dias
  template:
    metadata:
      labels: 
        workload: "spot"
        node-type: "spot"
      annotations:
        karpenter.sh/capacity-type: spot
    spec:
      requirements:
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["spot"]
        - key: "node.kubernetes.io/instance-type"
          operator: In
          values: ["m5.large", "m5.xlarge", "m5.2xlarge", "c5.large", "c5.xlarge", "t3.medium", "t3.large"]
      nodeClassRef: { name: default }
      taints:
        - key: "workload"
          value: "spot"
          effect: "NoSchedule"
  limits: { cpu: "1000", memory: 4000Gi }
---
# NodePool para observability
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata: { name: observability }
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 60s
    expireAfter: 2160h  # 90 dias
  template:
    metadata:
      labels: 
        workload: "observability"
        node-type: "on-demand"
      annotations:
        karpenter.sh/capacity-type: on-demand
    spec:
      requirements:
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["on-demand"]
        - key: "node.kubernetes.io/instance-type"
          operator: In
          values: ["r5.large", "r5.xlarge", "r5.2xlarge", "m5.large", "m5.xlarge"]
      nodeClassRef: { name: default }
      taints:
        - key: "workload"
          value: "observability"
          effect: "NoSchedule"
  limits: { cpu: "200", memory: 1000Gi }
```

`clusters/prod/autoscaling/karpenter/nodepool-spot.yaml`

```yaml
# NodePool específico para workloads tolerantes a preempção
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata: { name: batch-processing }
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
    expireAfter: 2160h  # 90 dias
  template:
    metadata:
      labels: 
        workload: "batch"
        node-type: "spot"
      annotations:
        karpenter.sh/capacity-type: spot
    spec:
      requirements:
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["spot"]
        - key: "node.kubernetes.io/instance-type"
          operator: In
          values: ["m5.large", "m5.xlarge", "m5.2xlarge", "c5.large", "c5.xlarge", "t3.medium", "t3.large", "t3.xlarge"]
      nodeClassRef: { name: default }
      taints:
        - key: "workload"
          value: "batch"
          effect: "NoSchedule"
  limits: { cpu: "2000", memory: 8000Gi }
```

---

## 8) **Storage & Backup/DR**

### StorageClasses (EBS/EFS com criptografia)

`clusters/prod/storage/storageclasses.yaml`

```yaml
# StorageClass para workloads críticos (gp3)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: gp3-encrypted }
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  iops: "3000"
  throughput: "125"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
---
# StorageClass para workloads de baixo custo (gp2)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: gp2-encrypted }
provisioner: ebs.csi.aws.com
parameters:
  type: gp2
  encrypted: "true"
  kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
---
# StorageClass para EFS (shared storage)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: efs-sc }
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxxxxxx
  directoryPerms: "0755"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
reclaimPolicy: Retain
volumeBindingMode: Immediate
---
# StorageClass para backups (S3)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: s3-backup }
provisioner: s3.csi.aws.com
parameters:
  bucket: obraflow-backups
  region: us-east-1
  prefix: "k8s-backups/"
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

### Velero (backup)

`clusters/prod/storage/velero/values.yaml`

```yaml
configuration:
  provider: aws
  backupStorageLocation:
    - name: default
      bucket: obraflow-backups
      config: 
        region: us-east-1
        s3ForcePathStyle: "true"
        kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  volumeSnapshotLocation:
    - name: default
      provider: aws
      config: 
        region: us-east-1
        kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
schedules:
  # Backup diário dos dados críticos
  daily-data:
    schedule: "0 3 * * *"
    template:
      ttl: 168h  # 7 dias
      includedNamespaces: ["obraflow-data"]
      excludedResources: ["events", "secrets"]
      labelSelector:
        matchLabels:
          backup: "true"
  # Backup semanal completo
  weekly-full:
    schedule: "0 2 * * 0"
    template:
      ttl: 720h  # 30 dias
      includedNamespaces: ["obraflow-app", "obraflow-data", "observability"]
      excludedResources: ["events"]
  # Backup mensal para arquivo
  monthly-archive:
    schedule: "0 1 1 * *"
    template:
      ttl: 2160h  # 90 dias
      includedNamespaces: ["obraflow-app", "obraflow-data", "observability"]
      excludedResources: ["events", "secrets"]
---
# BackupPolicy para recursos específicos
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: obraflow-critical-backup
  namespace: velero
spec:
  includedNamespaces: ["obraflow-data"]
  excludedResources: ["events", "secrets"]
  labelSelector:
    matchLabels:
      backup: "true"
  ttl: 168h
  storageLocation: default
  volumeSnapshotLocations: ["default"]
---
# RestorePolicy para testes de DR
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: obraflow-test-restore
  namespace: velero
spec:
  backupName: obraflow-critical-backup
  includedNamespaces: ["obraflow-data"]
  excludedResources: ["events", "secrets"]
  namespaceMapping:
    obraflow-data: obraflow-data-test
```

---

## 9) **Gateways e Ingress**

`clusters/prod/apps/gateways/obraflow-gw.yaml`

```yaml
# Gateway principal para API
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata: { name: obraflow-gw, namespace: istio-system }
spec:
  selector: { istio: ingressgateway }
  servers:
    - port: { number: 443, name: https, protocol: HTTPS }
      hosts: ["api.obraflow.example"]
      tls: { mode: SIMPLE, credentialName: tls-api-obraflow }
    - port: { number: 80, name: http, protocol: HTTP }
      hosts: ["api.obraflow.example"]
      tls: { httpsRedirect: true }
---
# Gateway para observability (interna)
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata: { name: observability-gw, namespace: istio-system }
spec:
  selector: { istio: ingressgateway }
  servers:
    - port: { number: 443, name: https, protocol: HTTPS }
      hosts: ["grafana.obraflow.example", "prometheus.obraflow.example"]
      tls: { mode: SIMPLE, credentialName: tls-observability-obraflow }
---
# VirtualService para API
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata: { name: obraflow-api, namespace: istio-system }
spec:
  hosts: ["api.obraflow.example"]
  gateways: ["obraflow-gw"]
  http:
    - match:
        - uri:
            prefix: "/api/v1"
      route:
        - destination:
            host: bff.obraflow-app.svc.cluster.local
            port: { number: 8080 }
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
    - match:
        - uri:
            prefix: "/health"
      route:
        - destination:
            host: bff.obraflow-app.svc.cluster.local
            port: { number: 8080 }
      timeout: 5s
---
# VirtualService para observability
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata: { name: observability, namespace: istio-system }
spec:
  hosts: ["grafana.obraflow.example", "prometheus.obraflow.example"]
  gateways: ["observability-gw"]
  http:
    - match:
        - uri:
            prefix: "/grafana"
      route:
        - destination:
            host: grafana.observability.svc.cluster.local
            port: { number: 3000 }
    - match:
        - uri:
            prefix: "/prometheus"
      route:
        - destination:
            host: prometheus.observability.svc.cluster.local
            port: { number: 9090 }
---
# DestinationRule para API
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata: { name: bff, namespace: istio-system }
spec:
  host: bff.obraflow-app.svc.cluster.local
  trafficPolicy:
    tls: { mode: ISTIO_MUTUAL }
    connectionPool:
      tcp: { maxConnections: 100 }
      http: { http1MaxPendingRequests: 50, maxRequestsPerConnection: 2 }
    circuitBreaker:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

---

## 10) **FinOps & Tagging**

### Labels/Annotations Obrigatórios

```yaml
# Labels obrigatórios para todos os recursos
labels:
  obraflow.io/cost-center: "obraflow-app"           # Centro de custo
  obraflow.io/component: "work-management"          # Componente específico
  obraflow.io/env: "prod"                           # Ambiente
  obraflow.io/tenant: "shared"                      # Tenant
  obraflow.io/team: "platform"                      # Time responsável
  obraflow.io/criticality: "high"                   # Criticidade (high/medium/low)
  obraflow.io/data-classification: "internal"       # Classificação de dados
  obraflow.io/backup: "true"                        # Se deve ser incluído no backup
  obraflow.io/monitoring: "true"                    # Se deve ser monitorado
  obraflow.io/auto-scale: "true"                    # Se pode ser auto-escalado
```

### Annotations para FinOps

```yaml
annotations:
  obraflow.io/cost-allocation: "work-management"    # Alocação de custo
  obraflow.io/budget: "1000"                        # Orçamento em USD
  obraflow.io/owner: "platform-team@obraflow.com"   # Responsável
  obraflow.io/created-by: "terraform"               # Ferramenta de criação
  obraflow.io/last-updated: "2025-01-15"           # Última atualização
  obraflow.io/retention: "90d"                      # Período de retenção
  obraflow.io/compliance: "lgpd,iso27001"          # Compliance requirements
```

### Relatórios de Custo

* **AWS CUR + Athena/QuickSight**: Análise por namespace, componente e tenant
* **GCP Billing Export + BigQuery/Looker**: Dashboards de custo por time
* **Kubecost/OpenCost**: Métricas de custo em tempo real
* **Alertas**: Notificações quando custo excede orçamento

---

## 11) **Pipeline CI (GitHub Actions) — CD GitOps**

`.github/workflows/cd-gitops.yml` (trecho)

```yaml
name: CD GitOps
on:
  push:
    branches: [main]
    paths:
      - "infra/**"
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: kubeval/kubeconform
        uses: azure/k8s-lint@v1
        with: { manifests: "infra/**.yaml" }
      - name: helm lint
        run: |
          helm lint infra/charts/obraflow-service
      - name: kustomize build
        run: |
          cd infra/clusters/prod && kubectl kustomize .
  notify-argocd:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ArgoCD image updater (opcional)
        run: echo "ArgoCD irá reconvergir automaticamente."
```

---

## 12) **Scripts utilitários**

`scripts/bootstrap-argocd.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
kubectl create ns argocd || true
kubectl apply -n argocd -k clusters/prod/apps/argocd
kubectl apply -f clusters/prod/apps/app-of-apps/application.yaml
echo "ArgoCD bootstrapped."
```

`scripts/validate.sh`

```bash
#!/usr/bin/env bash
set -e
helm lint charts/obraflow-service
kustomize build clusters/prod | kubeconform -strict -summary -
```

---

## 13) **Boas práticas operacionais**

* **Segredos** via External Secrets; sem `Secret` fixo em repo.
* **Probes** e **recursos** padronizados no chart; falhas de lint bloqueiam PR.
* **mTLS** estrito; **AuthZ** por SA (Istio).
* **Política de retry/backoff** e **timeouts** em *DestinationRule* / *VirtualService* (consistente com Manifesto 1).
* **ServiceMonitor** padrão para Prometheus (Manifesto 4).
* **ServiceAccount IAM Roles** para acesso a buckets/SM.
* **Backups Velero** testados trimestralmente (*restore drills*).
* **PDB/HPA/Karpenter** revisados por SLO e custo.

---

## 14) **Exemplo de aplicação de serviço com secrets e mesh**

`clusters/prod/externalsecrets/obraflow-app-secrets.yaml`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: { name: work-mgmt-secrets, namespace: obraflow-app }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: cloud-secrets, kind: ClusterSecretStore }
  target: { name: work-mgmt-env }
  data:
    - secretKey: DATABASE_URL
      remoteRef: { key: prod/obraflow/work-mgmt/db_url }
```

No `values.yaml` do Helm:

```yaml
env:
  - name: DATABASE_URL
    valueFrom: { secretKeyRef: { name: work-mgmt-env, key: DATABASE_URL } }
```

---

### Amarrações (com os Manifestos anteriores)

* **NFR/SLO (Manif. 1):** HPA, PDB, *timeouts/retries*, *rate-limit*, *quotas* e *mesh mTLS* suportam os SLOs.
* **Eventos (Manif. 2):** políticas de rede/segurança garantem Kafka seguro; *ServiceMonitor* e *lag* em dashboards.
* **Segurança/LGPD (Manif. 3):** PodSecurity `restricted`, NetworkPolicy default-deny, External Secrets, SC encriptadas, Velero com retenção.
* **Observabilidade (Manif. 4):** Collector/Prom/Loki/Tempo integrados; labels e exemplars coerentes.
* **APIs (Manif. 5):** Istio fornece *rate-limit* e *circuit break* coerentes com a *API Governance*.

## 🔄 Integração com Padrões do Monorepo

### Estrutura de Infraestrutura Aplicada
```
obraflow/
├── infra/
│   ├── clusters/                    # Kustomize por ambiente
│   ├── charts/                      # Helm charts padronizados
│   ├── argo-apps/                   # ArgoCD applications
│   └── scripts/                     # Scripts de automação
├── .github/workflows/
│   ├── cd-gitops.yml               # Pipeline de infraestrutura
│   └── security-scan.yml           # Validação de segurança
└── tools/scripts/infra/            # Scripts de infraestrutura
```

### Padrões de Infraestrutura por Linguagem
- **TypeScript**: Helm charts com valores padronizados, validação de schemas
- **Go**: Scripts de automação, validação de recursos Kubernetes
- **Cross-cutting**: GitOps com ArgoCD, validação de políticas

### Critérios de Aceite de Infraestrutura
- **Recursos Kubernetes** validados com kubeconform
- **Helm charts** com linting e validação de valores
- **Políticas de segurança** aplicadas via Gatekeeper
- **GitOps** funcionando com ArgoCD

---

Posso seguir com o **Manifesto 7 — *Test Strategy (Pirâmide + CDC + E2E + Performance + Chaos)*** ou prefere que eu ajuste algum ponto do baseline de Infra/GitOps antes?
