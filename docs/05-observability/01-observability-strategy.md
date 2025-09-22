# Manifesto 4 — **Observability Charter (RED/USE) + OTel Collector + Dashboards + Alertas**

*(ObraFlow · pacote inicial completo, integrado com padrões do monorepo multilíngue)*

Este manifesto de observabilidade foi **integrado com os padrões técnicos** definidos no plano de ação do monorepo, garantindo alinhamento entre arquitetura, desenvolvimento e operações. Inclui: **traces, métricas e logs** com **OpenTelemetry** (apps) → **Collector** → **Tempo/Jaeger**, **Prometheus/Mimir**, **Loki** e **Grafana**. Inclui **padrões RED/USE**, **correlação** (trace\_id / correlation\_id / tenant\_id / site\_id), **amostragem**, **dashboards JSON**, **regras de alerta** e **exemplos de instrumentação** (NestJS e Go/Echo).

## 📊 Integração com Padrões de Observabilidade do Monorepo

### Stack de Observabilidade Integrada
- **Traces**: OpenTelemetry → Tempo/Jaeger com correlação ponta-a-ponta
- **Métricas**: Prometheus/Mimir com exemplars para correlação
- **Logs**: Loki com logs estruturados (Pino/Zap)
- **Dashboards**: Grafana com painéis por domínio e tenant
- **Alertas**: Regras Prometheus baseadas em SLOs

### Padrões de Instrumentação Aplicados
- **TypeScript**: Pino logger com traceId binding, OTel auto-instrumentation
- **Go**: Zap logger com campos padrão, OTel SDK com propagators
- **Cross-cutting**: Correlação de traces, métricas RED/USE, logs estruturados

---

## 📁 Estrutura de arquivos

```
observability/
  README.md
  otel-collector/
    otel-collector.yaml
    kustomization.yaml
  grafana/
    dashboards/
      obraflow-red-overview.json
      obraflow-sync-mobile.json
      obraflow-kafka-health.json
      obraflow-slo-burn.json
    datasources/
      prometheus.yaml
      loki.yaml
      tempo.yaml
  prometheus/
    recording-rules.yaml
    alerting-rules.yaml
  loki/
    promtail-config.yaml
    logfmt-example.md
  examples/
    node-nestjs/otel.bootstrap.ts
    go-echo/otel.go
    logging/
      pino.ts
      zap.go
  probes/
    synthetics-k6.js
  guidelines.md
```

---

## 1) `observability/README.md` — Guia de uso

```markdown
# Observability — ObraFlow

Arquitetura: Apps (OTel SDK) → **OTLP** → OTel Collector →
• **Traces**: Tempo/Jaeger
• **Métricas**: Prometheus/Mimir (+ exemplars → traces)
• **Logs**: Loki (via Promtail ou OTLP logs)

## RED/USE — Padronização
- **RED (Request)**: Rate, Errors, Duration por **rota** e **serviço**.
- **USE (Resource)**: Utilização, Saturação, Erros por **recursos** (CPU, memória, pool DB, filas, Kafka lag etc).
- **Business Metrics**: OS concluídas, custo por OS, taxa de retrabalho, tempo de sincronização mobile.
- **SLO Metrics**: Error budget burn rate, availability, latency percentiles.

## Atributos obrigatórios (resource/labels)
- `service.name`, `service.version`, `deployment.environment` (dev|hml|prd)
- `tenant_id`, `site_id` (quando aplicável), `correlation_id`, `causation_id`
- `http.route`, `http.method`, `http.status_code`, `messaging.system` (kafka), `messaging.destination`
- `user.id`, `user.role`, `work_order.id`, `resource.type`, `cost_center`
- `ai.model`, `ai.provider`, `ai.cost_tokens`, `ai.latency_ms`

## Fluxo recomendado para logs
1) **stdout JSON estruturado** (Pino/Zap)
2) **Promtail** → **Loki** (parsers + labels)
3) Correlação: `trace_id`, `span_id`, `correlation_id` (enriquecidos no logger)

## Amostragem & custo
- **Traces**: parent-based + probabilistic (prod: 10–20%, hml/dev: 100%)
- **Métricas**: sempre on; usar *recording rules* p/ reduzir cardinalidade
- **Logs**: sampling por nível (error=100%, warn=50%, info=10%) + retenção 30–90d
- **Business Events**: 100% para eventos críticos (OS, medições, pagamentos)
- **AI/ML Events**: 100% para custos e latência, 10% para usage patterns
- **Correlação**: exemplars automáticos para métricas de alta cardinalidade
```

---

## 2) `otel-collector/otel-collector.yaml` — Collector (traces, metrics, logs)

> **Contrib distro** (componentes estáveis). Inclui **exemplars** para correlacionar métricas ↔ traces.

```yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
      grpc:
        endpoint: 0.0.0.0:4317
  prometheus:
    config:
      scrape_configs:
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs: [{ role: pod }]
          relabel_configs:
            - action: keep
              source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              regex: "true"
            - action: replace
              source_labels: [__meta_kubernetes_namespace]
              target_label: kubernetes_namespace
            - action: replace
              source_labels: [__meta_kubernetes_pod_name]
              target_label: pod
  # (opcional) logs via OTLP — se preferir OTLP logs ao invés de promtail
  # filelog:
  #   include: [ /var/log/containers/*.log ]
  #   operators: []

processors:
  memory_limiter:
    check_interval: 5s
    limit_percentage: 75
    spike_limit_percentage: 15
  batch:
    timeout: 1s
    send_batch_size: 1000
  attributes/normalize:
    actions:
      - key: deployment.environment
        action: upsert
        value: ${DEPLOY_ENV}
  # Amostragem parent-based + probabilística
  probabilistic_sampler:
    sampling_percentage: 15
  resource:
    attributes:
      - key: k8s.cluster.name
        action: upsert
        value: ${CLUSTER_NAME}
      - key: service.namespace
        action: insert
        from_attribute: k8s.namespace.name

exporters:
  otlp/tempo:
    endpoint: http://tempo:4317
    tls: { insecure: true }
  prometheus:
    endpoint: 0.0.0.0:8889
    enable_open_metrics: true
    resource_to_telemetry_conversion:
      enabled: true
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    default_labels_enabled:
      exporter: true
      job: true

extensions:
  health_check: {}
  pprof: { endpoint: :1777 }
  zpages: { endpoint: :55679 }

service:
  extensions: [health_check, pprof, zpages]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, attributes/normalize, probabilistic_sampler, batch]
      exporters: [otlp/tempo]
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, attributes/normalize, batch]
      exporters: [prometheus]
    logs:
      receivers: [otlp]   # ou filelog
      processors: [memory_limiter, attributes/normalize, batch]
      exporters: [loki]
```

`otel-collector/kustomization.yaml` (implantação rápida via Kustomize):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
configMapGenerator:
  - name: otel-collector-config
    files:
      - otel-collector.yaml
generatorOptions:
  disableNameSuffixHash: true
```

---

## 3) `grafana/dashboards/*.json` — Dashboards

### 3.1 `obraflow-red-overview.json` (resumo RED)

* **Painéis**:

  1. **RPS por serviço/rota** (`rate(http_requests_total[1m])`)
  2. **Erro 5xx %**
  3. **p95 Latência por rota** (`histogram_quantile(0.95, sum by (le,route)(rate(http_server_duration_seconds_bucket[5m])))`)
  4. **Exemplars de trace** (vincular datasource Tempo)
  5. **DB pool in use / saturation**
  6. **Fila de Outbox / Lag Kafka**

*(JSON completo pronto para colar; abreviado aqui para foco técnico.)*

```json
{
  "title": "ObraFlow — RED Overview",
  "panels": [
    {
      "type": "timeseries",
      "title": "RPS por rota",
      "targets": [
        { "expr": "sum by (service, route) (rate(http_requests_total{env=\"prd\"}[1m]))" }
      ]
    },
    {
      "type": "timeseries",
      "title": "Erro 5xx (%)",
      "targets": [
        { "expr": "sum(rate(http_requests_total{env=\"prd\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{env=\"prd\"}[5m])) * 100" }
      ]
    },
    {
      "type": "timeseries",
      "title": "p95 Latência por rota",
      "datasource": "Prometheus",
      "fieldConfig": { "defaults": { "unit": "ms" } },
      "targets": [
        { "expr": "histogram_quantile(0.95, sum by (le,route) (rate(http_server_duration_seconds_bucket{env=\"prd\"}[5m])) ) * 1000" }
      ],
      "options": { "legend": { "displayMode": "table" } }
    },
    {
      "type": "traces",
      "title": "Traces recentes (exemplar)",
      "datasource": "Tempo"
    }
  ],
  "schemaVersion": 38
}
```

### 3.2 `obraflow-sync-mobile.json` (staleness e sucesso de sync)

* **Painéis**: Staleness (`mobile:sync:staleness`), taxa de falha de sync, latência p95 do endpoint de sync, backlog de filas.

### 3.3 `obraflow-kafka-health.json` (Kafka)

* **Painéis**: Lag por consumer-group, taxa de processamento, DLQ rate, tamanho de Outbox.

### 3.4 `obraflow-slo-burn.json` (Error Budget)

* **Painéis**: SLO met vs burn rate (fast/slow burn), janelas 1h/6h/24h.

---

## 4) `prometheus/recording-rules.yaml` & `alerting-rules.yaml`

```yaml
groups:
  - name: obraflow-recording
    interval: 30s
    rules:
      - record: route:latency:p95
        expr: histogram_quantile(0.95, sum by (le, route) (rate(http_server_duration_seconds_bucket{env="prd"}[5m])))
      - record: api:error:rate
        expr: sum(rate(http_requests_total{env="prd",status=~"5.."}[5m])) / sum(rate(http_requests_total{env="prd"}[5m]))
      - record: kafka:consumer:lag
        expr: max without (topic,partition) (kafka_consumergroup_lag)
      - record: mobile:sync:staleness
        expr: max by(tenant,site) (timestamp() - last_successful_sync_timestamp_seconds)

  - name: obraflow-alerting
    interval: 1m
    rules:
      - alert: LatencyP95Breaching
        expr: route:latency:p95 > 0.3
        for: 10m
        labels: {severity: page}
        annotations:
          summary: "p95 > 300ms"
          description: "Rota {{ $labels.route }} com p95={{ $value }}s"

      - alert: ErrorRateHigh
        expr: api:error:rate > 0.01
        for: 10m
        labels: {severity: page}
        annotations:
          summary: "Erro 5xx > 1%"
          description: "Verificar serviços e deploy recente."

      - alert: KafkaLagGrowing
        expr: kafka:consumer:lag > 1000
        for: 10m
        labels: {severity: ticket}
        annotations:
          summary: "Kafka lag > 1000"
          description: "Consumidores atrasados; verificar DLQ/backpressure."

      - alert: MobileSyncStaleness
        expr: mobile:sync:staleness > 60
        for: 15m
        labels: {severity: ticket}
        annotations:
          summary: "Sync mobile > 60s"
          description: "Backlog em filas ou conectividade; verificar outbox/fila."
```

---

## 5) `loki/promtail-config.yaml` & `loki/logfmt-example.md`

**Promtail** (coleta logs dos containers, adicionando labels úteis):

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /run/promtail/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: kubernetes-pods
    pipeline_stages:
      - docker: {}
      - labeldrop:
          - filename
      - json:
          expressions:
            level: level
            msg: msg
            trace_id: trace_id
            correlation_id: correlation_id
            tenant_id: tenant_id
            site_id: site_id
      - labels:
          level:
          trace_id:
          correlation_id:
          tenant_id:
          site_id:
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - action: replace
        source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - action: replace
        source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
```

`logfmt-example.md` (campos obrigatórios do log JSON):

```markdown
{
  "ts":"2025-09-21T12:00:00Z",
  "level":"info",
  "msg":"work order created",
  "service":"work-management",
  "correlation_id":"co-123",
  "trace_id":"abc123def456...",
  "tenant_id":"acme",
  "site_id":"obra-sp-01",
  "route":"/api/work-orders",
  "user":"u-789"
}
```

---

## 6) Exemplos de **instrumentação**

### 6.1 `examples/node-nestjs/otel.bootstrap.ts`

```ts
// Inicialização OTel (traces + metrics) para NestJS (BFF/Serviços)
import 'reflect-metadata';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader, MeterProvider } from '@opentelemetry/sdk-metrics';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.SERVICE_NAME ?? 'bff',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.SERVICE_VERSION ?? '0.1.0',
    'deployment.environment': process.env.DEPLOY_ENV ?? 'dev',
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT ?? 'http://otel-collector:4318/v1/traces',
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT ?? 'http://otel-collector:4318/v1/metrics',
    }),
    exportIntervalMillis: 10000,
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      // reduz cardinalidade
      '@opentelemetry/instrumentation-http': { requireParentforOutgoingSpans: false },
      '@opentelemetry/instrumentation-express': { enabled: true },
      '@opentelemetry/instrumentation-pg': { enabled: true }
    }),
  ],
});

export async function startOtel() {
  await sdk.start();
  // Opcional: expose meter para métricas customizadas
  const meterProvider = new MeterProvider();
  return { shutdown: () => sdk.shutdown() };
}
```

**Uso no NestJS `main.ts`**:

```ts
import { startOtel } from './otel.bootstrap';
(async () => {
  const otel = await startOtel();
  // ... bootstrap NestFactory ...
  // process.on('SIGTERM', () => otel.shutdown());
})();
```

### 6.2 `examples/go-echo/otel.go`

```go
package observability

import (
  "context"
  "go.opentelemetry.io/otel"
  "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
  "go.opentelemetry.io/otel/sdk/resource"
  sdktrace "go.opentelemetry.io/otel/sdk/trace"
  "go.opentelemetry.io/otel/semconv/v1.21.0"
  "time"
)

func Setup(service string, version string, env string) (func(context.Context) error, error) {
  exp, err := otlptracehttp.New(context.Background(),
    otlptracehttp.WithEndpoint("otel-collector:4318"),
    otlptracehttp.WithInsecure(),
  )
  if err != nil { return nil, err }

  res, _ := resource.New(context.Background(),
    resource.WithAttributes(
      semconv.ServiceName(service),
      semconv.ServiceVersion(version),
      semconv.DeploymentEnvironment(env),
    ),
  )

  tp := sdktrace.NewTracerProvider(
    sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(0.15))),
    sdktrace.WithBatcher(exp, sdktrace.WithMaxExportBatchSize(1000), sdktrace.WithBatchTimeout(1*time.Second)),
    sdktrace.WithResource(res),
  )
  otel.SetTracerProvider(tp)
  return tp.Shutdown, nil
}
```

---

## 7) **Logging** com correlação

### 7.1 `examples/logging/pino.ts` (Node)

```ts
import pino from 'pino';
export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  formatters: {
    level(label) { return { level: label } }
  },
  base: {
    service: process.env.SERVICE_NAME,
    service_version: process.env.SERVICE_VERSION,
    env: process.env.DEPLOY_ENV
  },
  mixin() {
    // injeta trace_id/span_id do contexto OTel, se disponível
    const active = (global as any).otel?.context?.active?.();
    const trace = active?.getValue?.({}) || {};
    return {
      trace_id: trace?.trace_id,
      span_id: trace?.span_id
    };
  },
  redact: { paths: ['password', 'token', 'authorization', '*.cpf', '*.email'], remove: true }
});
```

### 7.2 `examples/logging/zap.go` (Go)

```go
logger, _ := zap.NewProduction(zap.Fields(
  zap.String("service", os.Getenv("SERVICE_NAME")),
  zap.String("service_version", os.Getenv("SERVICE_VERSION")),
  zap.String("env", os.Getenv("DEPLOY_ENV")),
))
// adicionar trace_id via middleware que lê do contexto OTel
```

---

## 8) `probes/synthetics-k6.js` — Sondagem sintética (user journey)

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
export const options = {
  scenarios: {
    journey: { executor: 'constant-vus', vus: 5, duration: '3m' }
  },
  thresholds: { 'http_req_duration': ['p(95)<300'] }
};

const BASE = __ENV.ENDPOINT;

export default function () {
  const res1 = http.get(`${BASE}/health`);
  check(res1, { 'health 200': r => r.status === 200 });

  const res2 = http.get(`${BASE}/api/work-orders?status=SCHEDULED`);
  check(res2, { 'wo list ok': r => r.status === 200 });

  sleep(1);
}
```

---

## 9) `guidelines.md` — Diretrizes operacionais

```markdown
# Diretrizes

## Naming de métricas HTTP
- `http_requests_total{service,route,method,status}`
- `http_server_duration_seconds_bucket{service,route,method}` (histograma)
- `work_queue_depth{queue}`

## Conexão com SLOs
- Latência p95 e error rate alimentam **SLO LatencyP95** e **ErrorRateHigh**.
- `mobile:sync:staleness` alimenta SLO de sync (Manifesto 1).

## Boas práticas
- Evitar alta cardinalidade: normalizar `route` (sem IDs).
- Exemplars ligados a `trace_id` para *drill-down*.
- Logs sem PII (ver Manifesto 3), com `tenant_id` e `site_id`.
```

---

### Observações de amarração (C4/UX/SLO)

* **BFF/Serviços** exportam métricas RED por rota e **traces** com *baggage* `tenant_id/site_id`.
* **Dashboards** refletem as **telas críticas** (e.g., *Minhas OS*, *Sync Mobile*, *Medições*).
* **Alertas** mapeiam os **SLOs** do Manifesto 1 e **incidentes** do Manifesto 3.

## 🔄 Integração com Padrões do Monorepo

### Estrutura de Observabilidade Aplicada
```
obraflow/
├── libs/
│   ├── ts/otel-sdk/               # OTel setup (Node/Browser)
│   ├── ts/logging-pino/           # Logger Pino com traceId
│   └── go/pkg/otel/               # OTel setup Go
├── observability/
│   ├── otel-collector/            # Collector config
│   ├── grafana/                   # Dashboards
│   ├── prometheus/                # Rules e alerts
│   └── loki/                      # Log config
└── tools/scripts/observability/   # Scripts de setup
```

### Padrões de Instrumentação por Linguagem
- **TypeScript**: OTel auto-instrumentation, Pino com traceId binding
- **Go**: OTel SDK com propagators, Zap com campos padrão
- **Cross-cutting**: Correlação de traces, métricas RED/USE, logs estruturados

### Critérios de Aceite de Observabilidade
- **Cada request** tem traceId visível ponta-a-ponta
- **Dashboards** com p95/err rate por serviço e tenant
- **Logs estruturados** com correlation_id, tenant_id, site_id
- **Métricas RED/USE** padronizadas por domínio

---

Deseja que eu **prossiga com o Manifesto 5 — *API Governance (OpenAPI/GraphQL) + Resiliência/Contratos*** ou prefere algum ajuste neste pacote de Observabilidade?
