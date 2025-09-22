# Manifesto 1 — **NFR Charter (ATAM) + SLIs/SLOs + Validação**

*(ObraFlow · versão macro completa, integrada com padrões do monorepo multilíngue)*

Este manifesto de requisitos não-funcionais (NFR) foi **integrado com os padrões técnicos** definidos no plano de ação do monorepo, garantindo alinhamento entre arquitetura, desenvolvimento e operações. Inclui: **charter em YAML**, guia explicativo, **SLIs/SLOs** e **regras Prometheus**, **esqueleto de testes de carga (k6)**, **experimentos de caos** e **checklist de aceite**.

## 🏗️ Integração com Padrões do Monorepo

### Stack Tecnológica Integrada
- **Frontend**: Next.js 14 (App Router) + React Native/Expo (offline-first)
- **Backend**: NestJS (BFF) + Go Echo + Fx + Watermill (microserviços)
- **Observabilidade**: OpenTelemetry → Tempo/Jaeger + Prometheus + Loki + Grafana
- **Dados**: PostgreSQL (RLS multi-tenant) + MongoDB + Redis + TimescaleDB
- **CI/CD**: GitHub Actions + Nx + pnpm + Changesets

### Padrões de Qualidade Aplicados
- **Testes**: Cobertura ≥80% (unit + integration + e2e)
- **Observabilidade**: TraceId ponta-a-ponta, métricas p95/p99
- **Segurança**: SAST, SBOM, image scanning, dependency review
- **Performance**: <100ms p95, >1000 RPS por tenant
- **Compliance**: LGPD, auditoria, trilha de alterações

---

## 📁 Estrutura de arquivos

```
docs/
  10-architecture/
    nfr-charter/
      README.md
      nfr-charter.yml
      sli-slo-rules.promql.yaml
      chaos/experiments.md
      test-load-k6/apontamento-create-smoke.js
      checklist.md
```

---

## 1) `nfr-charter.yml` — **Charter ATAM (executável por times)**

```yaml
meta:
  system: ObraFlow
  version: 0.1.0
  owners:
    - role: Architecture
      contact: architecture@obraflow.example
    - role: SRE
      contact: sre@obraflow.example
    - role: Security & Privacy
      contact: security@obraflow.example
  scope:
    environments: [dev, hml, prd]
    domains:
      - planning
      - work-management
      - resource-orchestration
      - procurement-inventory
      - quality-safety
      - measurement-billing
    critical_user_journeys:
      - "Apontar produção no campo (mobile) -> sincronizar -> aparecer em medições"
      - "Gerar/atribuir Ordem de Serviço -> alocar equipe/equipamento"
      - "Requisição -> OC -> Recebimento em canteiro"
      - "Rodar medição e solicitar aceite do fiscal"
    assumptions:
      - "Uso em campo com conectividade intermitente (4G/3G/edge wifi)"
      - "Multi-tenant com segregação lógica (RLS) e criptografia em trânsito/repouso"
      - "Backends distribuídos (Kubernetes) com observabilidade OTel"

quality_attributes:
  performance:
    sli:
      - id: PERF-API-P95
        name: "Latência p95 API BFF"
        measure: "histogram_quantile(0.95, sum by(le, route)(rate(http_server_duration_seconds_bucket{env='prd'}[5m])))"
        target_ms: 300
        warning_threshold_ms: 250
        critical_threshold_ms: 400
      - id: PERF-API-P99
        name: "Latência p99 API BFF"
        measure: "histogram_quantile(0.99, sum by(le, route)(rate(http_server_duration_seconds_bucket{env='prd'}[5m])))"
        target_ms: 500
        warning_threshold_ms: 400
        critical_threshold_ms: 800
      - id: PERF-MOBILE-SYNC
        name: "Staleness de sincronização mobile"
        measure: "max by(tenant,site)(timestamp() - last_successful_sync_timestamp_seconds)"
        target_seconds: 60
        warning_threshold_seconds: 45
        critical_threshold_seconds: 120
      - id: PERF-DB-CONNECTION
        name: "Tempo de conexão com banco"
        measure: "histogram_quantile(0.95, sum by(le)(rate(db_connection_duration_seconds_bucket[5m])))"
        target_ms: 50
        warning_threshold_ms: 30
        critical_threshold_ms: 100
      - id: PERF-KAFKA-LAG
        name: "Lag de processamento Kafka"
        measure: "max by(topic, consumer_group)(kafka_consumer_lag_sum)"
        target_seconds: 30
        warning_threshold_seconds: 15
        critical_threshold_seconds: 60
    capacity:
      peak_rps_web: 200
      peak_rps_mobile: 300
      burst_capacity_rps: 500
      growth_monthly_pct: 15
      concurrent_users: 5000
      data_ingestion_gb_per_hour: 100
    resource_limits:
      cpu_utilization_pct: 70
      memory_utilization_pct: 80
      disk_io_utilization_pct: 80
      network_bandwidth_mbps: 1000
    tactics: [cache, async-queue, bulkhead, connection-pool, compression, pagination, projection-cqrs, circuit-breaker, retry-with-backoff]
  availability:
    slo:
      - id: AV-WORK
        objective: 0.999
        applies_to: ["work-management", "bff"]
        error_budget_pct: 0.1
        burn_rate_fast: 2.0
        burn_rate_slow: 0.1
      - id: AV-SYNC
        objective: 0.995
        applies_to: ["sync-mobile"]
        error_budget_pct: 0.5
        burn_rate_fast: 1.5
        burn_rate_slow: 0.2
      - id: AV-DATA
        objective: 0.9999
        applies_to: ["postgres", "kafka"]
        error_budget_pct: 0.01
        burn_rate_fast: 3.0
        burn_rate_slow: 0.05
    rto: "2h"
    rpo: "15m"
    mttr: "15min"
    mtbf: "720h"
    health_checks:
      liveness: "5s"
      readiness: "10s"
      startup: "30s"
    tactics: [multi-az, hpa, pds, graceful-degradation, read-replicas, rate-limit, circuit-breaker, bulkhead, timeout]
  security:
    requirements:
      - oidc: true
      - mtls_mesh: true
      - secret_manager: "KMS/ExternalSecrets"
      - data_masking_logs: true
      - sbom_and_vuln_scan: true
      - zero_trust_network: true
      - data_classification: true
      - dlp_enabled: true
    controls:
      - "OWASP ASVS nível 2"
      - "CSP, HTTPS only, HSTS, JWT short-lived + JTI"
      - "PII vault + field level encryption quando aplicável"
      - "RBAC/ABAC com OPA/Rego"
      - "Audit logging para todas as operações críticas"
      - "Vulnerability scanning em CI/CD"
      - "Image signing com cosign"
      - "Network policies restritivas"
    sli:
      - id: SEC-VULN-SCAN
        name: "Tempo para scan de vulnerabilidades"
        measure: "max(vulnerability_scan_duration_seconds)"
        target_seconds: 300
      - id: SEC-AUTH-LATENCY
        name: "Latência de autenticação"
        measure: "histogram_quantile(0.95, sum by(le)(rate(auth_duration_seconds_bucket[5m])))"
        target_ms: 200
      - id: SEC-TOKEN-ROTATION
        name: "Frequência de rotação de tokens"
        measure: "max(token_age_seconds)"
        target_seconds: 86400
  privacy:
    lgpd:
      dpia_status: "Required"
      data_minimization: true
      retention_days_default: 365
      data_subject_rights_sla_days: 15
      pseudonymization: true
      anonymization: true
      data_residency: "Brazil/LATAM"
      consent_management: true
    sli:
      - id: PRIV-PII-REDACTION
        name: "Tempo para redação de PII"
        measure: "histogram_quantile(0.95, sum by(le)(rate(pii_redaction_duration_seconds_bucket[5m])))"
        target_ms: 1000
      - id: PRIV-DSR-RESPONSE
        name: "Tempo de resposta a DSR"
        measure: "max(dsr_response_time_seconds)"
        target_seconds: 1296000
      - id: PRIV-DATA-RETENTION
        name: "Conformidade com retenção de dados"
        measure: "sum(data_retention_violations_total)"
        target_count: 0
  observability:
    telemetry:
      tracing: "OpenTelemetry (OTLP)"
      metrics: "Prometheus (RED/USE), exemplars para tracing"
      logs: "Loki (JSON estruturado com correlation_id/tenant_id/site_id)"
      sampling: "1% traces, 100% errors, 10% business events"
    sli:
      - id: OBS-LOG-INGESTION
        name: "Tempo de ingestão de logs"
        measure: "histogram_quantile(0.95, sum by(le)(rate(log_ingestion_duration_seconds_bucket[5m])))"
        target_seconds: 5
      - id: OBS-METRIC-COLLECTION
        name: "Tempo de coleta de métricas"
        measure: "histogram_quantile(0.95, sum by(le)(rate(metric_collection_duration_seconds_bucket[5m])))"
        target_seconds: 30
      - id: OBS-ALERT-RESPONSE
        name: "Tempo de resposta a alertas"
        measure: "max(alert_response_time_seconds)"
        target_seconds: 300
      - id: OBS-DASHBOARD-LOAD
        name: "Tempo de carregamento de dashboards"
        measure: "histogram_quantile(0.95, sum by(le)(rate(dashboard_load_duration_seconds_bucket[5m])))"
        target_seconds: 3
    required_dimensions: ["tenant_id", "site_id", "role", "endpoint", "status_code"]
    error_budget_policy_ref: "../slo/error-budget-policy.md"  # opcional se existir
  maintainability:
    targets:
      coverage_min_pct: 80
      technical_debt_ratio: 0.05
      code_duplication_pct: 5
      cyclomatic_complexity: 10
    sli:
      - id: MAINT-DEPLOY-TIME
        name: "Tempo de deploy"
        measure: "histogram_quantile(0.95, sum by(le)(rate(deploy_duration_seconds_bucket[5m])))"
        target_seconds: 300
      - id: MAINT-TEST-EXECUTION
        name: "Tempo de execução de testes"
        measure: "max(test_execution_duration_seconds)"
        target_seconds: 600
  cost:
    targets:
      cost_per_request_r$: 0.01
      cost_per_gb_storage_r$: 0.50
      cost_per_user_month_r$: 50
      cost_anomaly_threshold_pct: 20
    sli:
      - id: COST-PER-REQUEST
        name: "Custo por requisição"
        measure: "rate(cost_total_r$[1h]) / rate(http_requests_total[1h])"
        target_r$: 0.01
      - id: COST-ANOMALY
        name: "Detecção de anomalia de custo"
        measure: "increase(cost_anomaly_detected_total[1h])"
        target_count: 0
      - id: COST-BUDGET-BURN
        name: "Burn rate do orçamento"
        measure: "rate(cost_budget_burn_rate[1h])"
        target_ratio: 0.1
      cyclomatic_avg_max: 10
      coupling_limit_note: "Aplicar DDD: coesão alta, acoplamento baixo"
    practices: [adr, api-contract-tests, spec-driven, codeowners, lint-biome, dep-updates]
  portability:
    containers: true
    k8s: "Helm/Kustomize"
    cloud: ["AWS", "GCP"]  # portável a múltiplos provedores
  cost:
    finops:
      cost_allocation_tags: ["tenant", "namespace", "service"]
      budgets:
        prd_monthly_usd: 15000
      guardrails:
        storage_retention_days: 90
        log_sampling: "error=100%, info=10%"
  accessibility:
    wcag: "2.2 AA"
    targets:
      mobile_target_size_px: 44
      contrast_min_ratio: ">=4.5:1"

scenarios:  # ATAM — cenário -> táticas -> medidas
  - id: PERF-01
    stimulus: "Pico 10x de criação de apontamentos em 15 min (campo)"
    environment: "prd"
    response: "Fila estabiliza sem perdas; p95 < 700ms; throughput sustentado"
    tactics: ["async-queue", "retry-backoff", "autoscaling", "bulkhead", "idempotency"]
    validation: ["k6: test-load-k6/apontamento-create-smoke.js", "Prometheus: PERF-API-P95"]
  - id: AV-01
    stimulus: "Falha de zona (AZ) do cluster"
    response: "SLO de disponibilidade mantido; RTO ≤ 2h; RPO ≤ 15m"
    tactics: ["multi-az", "stateful-ha", "backup-restore", "readiness-probes", "PDB"]
    validation: ["chaos/experiments.md#az-outage"]
  - id: SEC-01
    stimulus: "Token reutilizado (replay)"
    response: "Bloqueio por JTI + exp curto; auditoria e alerta"
    tactics: ["jwt-jti", "short-lived-tokens", "waf", "rate-limit"]
    validation: ["security tests", "SIEM alert"]

traceability:
  c4_components:
    - "BFF (NestJS)"
    - "Work-Management (NestJS)"
    - "Resource-Orchestration (Go/Echo)"
    - "Measurement & Billing (Go/Echo)"
  ux_critical_flows:
    - "Minhas OS (mobile) → apontar → sync → medição"
    - "Gantt/Curva S → publicar plano"
    - "Requisição → OC → Recebimento em canteiro"
```

---

## 2) `README.md` — **Guia de entendimento e uso**

```markdown
# NFR Charter — ObraFlow

Este documento estabelece *requisitos não-funcionais* e *mecanismos de validação* para o ObraFlow, alinhados ao ATAM e às práticas SRE (SLI/SLO/Error Budget).

## O que este charter cobre
- Qualidades: **desempenho, disponibilidade, segurança, privacidade, observabilidade, manutenibilidade, portabilidade, custo, acessibilidade**.
- SLIs/SLOs e regras Prometheus.
- Cenários ATAM com táticas e formas de validação (k6, chaos, métricas).
- Rastreabilidade com C4 e fluxos críticos de UX.

## Como usar
1. Ajuste metas por ambiente em `nfr-charter.yml`.
2. Carregue as regras de SLI/SLO (`sli-slo-rules.promql.yaml`) no Prometheus.
3. Execute o *smoke de carga* (`test-load-k6/apontamento-create-smoke.js`) antes de cada release.
4. Programe *experimentos de caos* (arquivo `chaos/experiments.md`) em janelas controladas.
5. Use o `checklist.md` como **Definition of Done** não-funcional por épico.

## Telemetria mínima (campos)
- **Traces**: `service.name`, `deployment.environment`, `enduser.id (hash)`, `tenant_id`, `site_id`, `http.route`, `http.status_code`, `error.type`.
- **Logs** (JSON): `timestamp`, `severity`, `message`, `correlation_id`, `tenant_id`, `site_id`, `pii_redacted=true`.
- **Métricas** (RED/USE): `http_server_duration_seconds_bucket`, `http_requests_total`, `work_queue_depth`, `db_pool_in_use`, `sync_staleness_seconds`.

## Políticas de resiliência (resumo)
- **Timeouts**: HTTP 2s (default), gRPC 1s; circuit breaker (50% fail / 60s).
- **Retry/Backoff**: máx. 3; 100ms, 250ms, 600ms; **idempotency-key** para POST críticos.
- **Bulkheads**: pools separados por integração; **rate-limit** por tenant.
- **Degradação graciosa**: projeções CQRS readonly quando medição estiver lenta.

## Aceite e auditoria
- Todo release deve anexar: print dos SLOs atendidos (últimos 30d), relatório k6 e resultado do experimento de caos obrigatório do ciclo.
```

---

## 3) `sli-slo-rules.promql.yaml` — **Regras Prometheus (recording & alerts)**

```yaml
groups:
  - name: obraflow-sli
    interval: 30s
    rules:
      - record: route:latency:p95
        expr: histogram_quantile(0.95, sum by (le, route) (rate(http_server_duration_seconds_bucket{env="prd"}[5m])))
      - record: api:error:rate
        expr: sum(rate(http_requests_total{env="prd",status=~"5.."}[5m])) / sum(rate(http_requests_total{env="prd"}[5m]))
      - record: mobile:sync:staleness
        expr: max by(tenant,site) (timestamp() - last_successful_sync_timestamp_seconds)

  - name: obraflow-slo
    interval: 1m
    rules:
      - alert: SLOLatencyP95Breaching
        expr: route:latency:p95 > 0.3  # 300ms
        for: 10m
        labels: {severity: page}
        annotations:
          summary: "p95 acima do objetivo (300ms)"
          description: "Rota {{ $labels.route }} com p95={{ $value }}s"

      - alert: APIErrorRateHigh
        expr: api:error:rate > 0.01
        for: 10m
        labels: {severity: page}
        annotations:
          summary: "Taxa de erro 5xx > 1%"
          description: "Verificar serviços afetados; correlação com deploy recente."

      - alert: MobileSyncStaleness
        expr: mobile:sync:staleness > 60
        for: 15m
        labels: {severity: ticket}
        annotations:
          summary: "Staleness de sync mobile > 60s"
          description: "Possível backlog de fila ou conectividade."
```

---

## 4) `test-load-k6/apontamento-create-smoke.js` — **Smoke de carga (k6)**

> Exercita o caminho crítico “apontar produção” com UI otimista, validando p95 e taxa de erro.

```javascript
import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';

export const options = {
  vus: 20,
  duration: '5m',
  thresholds: {
    'http_req_duration{scenario:apontamento}': ['p(95)<300'],
    'errors{scenario:apontamento}': ['rate<0.01'],
  },
};

const Endpoint = __ENV.ENDPOINT || 'https://api.obraflow.example';
const Token    = __ENV.TOKEN    || 'REPLACE_ME';
const Tenant   = __ENV.TENANT   || 'acme';
const Site     = __ENV.SITE     || 'obra-sp-01';

const errors = new Rate('errors', true);
const latency = new Trend('latency_ms');

export default function () {
  group('scenario:apontamento', () => {
    const woId = 'WO-2025-000123';
    const payload = {
      quantity: 5.5,
      unit: 'm2',
      timestamp: new Date().toISOString(),
      notes: 'k6 smoke load',
      offlineId: `k6-${__VU}-${__ITER}`,
    };

    const res = http.post(
      `${Endpoint}/api/work-orders/${woId}/productions`,
      JSON.stringify(payload),
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${Token}`,
          'x-tenant-id': Tenant,
          'x-site-id': Site,
          'x-idempotency-key': payload.offlineId,
        },
        tags: { scenario: 'apontamento' },
      }
    );

    latency.add(res.timings.duration);
    const ok = check(res, {
      'status is 2xx/3xx': (r) => r.status >= 200 && r.status < 400,
    });

    if (!ok) errors.add(1, { scenario: 'apontamento' });

    sleep(0.5);
  });
}
```

---

## 5) `chaos/experiments.md` — **Experimentos de Caos (Litmus/Gremlin/Kube-native)**

```markdown
# Experimentos de Caos — ObraFlow

## Objetivos
- Validar SLOs de disponibilidade/latência sob falhas realistas.
- Comprovar RTO/RPO declarados no charter.

## Experimento 1 — Queda de AZ (AV-01)
- **Hipótese**: Serviços permanecem disponíveis com SLO de 99.9% e RTO ≤ 2h.
- **Técnica**: Kube: cordon+drain dos nós de 1 zona + interrupção de rede entre pods selecionados.
- **Métricas**: error rate, p95, sucesso dos fluxos críticos, tempo de failover de StatefulSets.
- **Saída esperada**: nenhum dado perdido além de RPO 15m; alertas disparam e se normalizam.

## Experimento 2 — Degradação de Banco (PERF-01)
- **Hipótese**: Circuit breaker atua e projeções CQRS absorvem carga; p95 < 700ms.
- **Técnica**: Throttle de IOPS em primário; aumento de latência artificial.
- **Métricas**: fila de outbox, profundidade de filas, latência de leitura de projeções.

## Experimento 3 — Token Replay (SEC-01)
- **Hipótese**: JTI evita reuso; logs/auditoria geram alerta.
- **Técnica**: Reutilizar token expirado e repetido em endpoints protegidos.
- **Métricas**: taxa de 401/403, alerta SIEM, indicação de tentativa bloqueada.
```

---

## 6) `checklist.md` — **Definition of Done (NFR) por épico/release**

```markdown
# Checklist NFR — DoD

- [ ] SLIs/SLOs aderentes: últimos 30d atendem as metas (prints anexos).
- [ ] Regras Prometheus carregadas e alertas testados.
- [ ] Smoke de carga (k6) executado no ambiente alvo com sucesso (p95 e erros OK).
- [ ] 1 experimento de caos executado nesta janela de release; relatório anexado.
- [ ] Logs estruturados com `correlation_id`, `tenant_id`, `site_id` presentes.
- [ ] Idempotency-Key implementado nas rotas POST críticas.
- [ ] Timeouts/Retry/Circuit Breaker configurados conforme política.
- [ ] Cobertura de testes ≥ 80% no serviço impactado.
- [ ] DPIA atualizado (se novas PII surgiram) e retenção/mascaramento revisados.
- [ ] Acessibilidade validada (cheque contraste, foco, navegação por teclado).
- [ ] Custos estimados vs. orçamento (FinOps) analisados; guardrails revisados.
```

---

## 7) Integração com Padrões do Monorepo

### Estrutura de Diretórios Aplicada
```
obraflow/
├── apps/
│   ├── web-next/                  # Next.js 14 (App Router)
│   ├── mobile-expo/               # React Native/Expo (offline-first)
│   ├── bff-nest/                  # NestJS (API Gateway/BFF)
│   └── svc-accounts-go/           # Go Echo + Fx + Watermill
├── libs/
│   ├── ts/framework-core/         # DDD patterns (Result<T,E>, DomainError)
│   ├── ts/logging-pino/           # Logging estruturado com traceId
│   ├── ts/otel-sdk/               # OpenTelemetry (Node/Browser)
│   ├── ts/security/               # JWT, RBAC, guards
│   └── go/pkg/tenancy/            # Multi-tenancy
└── tools/generators/              # Nx generators customizados
```

### Padrões de Desenvolvimento Integrados
- **TypeScript**: Nx + pnpm + Biome (lint/format) + Jest/Vitest
- **Go**: go work (multi-módulo) + Taskfile + golangci-lint
- **Cross-cutting**: Logging estruturado (Pino/Zap), OTel, correlação de traces
- **Segurança**: JWT (RS256), RBAC, validação (Zod), SAST, SBOM
- **CI/CD**: GitHub Actions com caching, path filters, previews

### Critérios de Aceite do Monorepo
- **Testes**: unit ≥80%; integração E2E com trace propagation validada
- **Observabilidade**: cada request tem traceId visível ponta-a-ponta; dashboards com p95/err rate
- **Segurança**: scans sem CVEs de severidade alta; segredos ausentes no repo
- **DX**: generators funcionam; make/task unificados; nx graph atualizado

## 8) Observações finais (alinhamento com C4/UX)

* Os **SLIs/SLOs** aqui definidos cobrem os **fluxos críticos** descritos nas jornadas de UX (mobile e web).
* A telemetria exigida (OTel/Prom/Loki) corresponde aos **contêineres** do C4 (BFF, Work-Management, etc.).
* As **táticas** (queue/outbox, projections, bulkhead, rate-limit, circuit breaker) refletem as **decisões arquiteturais** (CQRS/ES, Sagas, multi-AZ).
* Os **padrões do monorepo** garantem consistência e qualidade em todas as camadas da aplicação.

---

Se estiver de acordo, **posso prosseguir com o Manifesto 2 — *Catálogo de Eventos (AsyncAPI)***, entregando o pacote com **esquema base**, **nomenclatura**, **versionamento**, **contratos de canais** e **exemplos de payloads** alinhados aos domínios. Quer que eu avance?
