# Manifesto 2 — **Catálogo de Eventos (AsyncAPI) + Naming + Versionamento + Contratos Kafka**

*(ObraFlow · pacote inicial completo, pronto para colar no repositório)*

A seguir está o **pacote base** do Catálogo de Eventos assíncronos, padronizando **envelopes**, **nomenclatura de tópicos**, **evolução de esquema**, **bindings Kafka**, **segurança/ACL**, **DLQ e retries**, além de **exemplos** e **teste de contratos**. Mantém alinhamento com C4/UX e o Manifesto 1 (NFR/SLOs).

---

## 📁 Estrutura de arquivos

```
docs/
  10-architecture/
    event-catalog-asyncapi/
      README.md
      asyncapi.yml
      naming-conventions.md
      versioning-policy.md
      testing-contracts.md
      security-acl.md
      retention-dlq-policy.md
      schemas/
        common/
          envelope.json
          ids.json
          enums.json
        work/
          WorkOrderCreated.json
          WorkOrderScheduled.json
        resource/
          ResourceReserved.json
          ResourceReservationExpired.json
        procurement/
          MaterialRequisitionSubmitted.json
          PurchaseOrderApproved.json
        measurement/
          WorkProgressUpdated.json
          MeasurementApproved.json
        quality/
          NonConformanceOpened.json
          QualityInspectionPassed.json
      examples/
        work/WorkOrderCreated.example.json
        resource/ResourceReserved.example.json
        procurement/MaterialRequisitionSubmitted.example.json
        measurement/MeasurementApproved.example.json
        quality/NonConformanceOpened.example.json
```

---

## 1) `README.md` — **Guia de uso do catálogo**

```markdown
# Catálogo de Eventos — ObraFlow (AsyncAPI + Kafka)

Este catálogo define os **contratos de eventos** do ObraFlow para integração entre domínios (DDD), Sagas e Outbox.
Inclui **envelope padrão**, **naming**, **versionamento**, **bindings Kafka**, **políticas de retenção/DLQ** e **exemplos**.

## Objetivos
- Consistência e compatibilidade de eventos (evolução segura).
- Observabilidade e rastreabilidade (correlation/causation id).
- Multi-tenant com isolamento lógico por partição e ACL.

## Como navegar
- `asyncapi.yml`: visão consolidada de canais, mensagens e bindings.
- `schemas/*/*.json`: JSON Schemas das cargas (`data`) por domínio.
- `naming-conventions.md`, `versioning-policy.md`: regras normativas.
- `retention-dlq-policy.md`: retries, DLQ e retenções.
- `testing-contracts.md`: estratégia CDC/validadores.

## Convenções chave
- **Envelope** inspirado em CloudEvents: `eventId` (ULID), `type`, `source`, `time`, `tenantId`, `correlationId`, `causationId`, `idempotencyKey`, `data`.
- **Topico**: `<domain>.<event>.<version>` (ex.: `work.work-order-created.v1`).
- **Partição**: por `tenantId` + `aggregateId` (chave composta).
- **Segurança**: SASL/SCRAM + ACLs por prefixo de tópico e consumer groups.
- **Validação**: Schema Registry com validação obrigatória e compatibilidade backward.
- **DLQ**: Tópicos `.dlq` com retry exponencial e dead letter após 3 tentativas.
- **Observabilidade**: Headers de tracing e métricas de negócio em cada evento.

## Rastros com C4/UX
- Eventos mapeiam os fluxos críticos (OS ↔ Alocação ↔ Medição ↔ Suprimentos ↔ Qualidade).
- Telemetria exigida no Manifesto 1 é suportada via headers e campos do envelope.

```

---

## 2) `naming-conventions.md` — **Nomenclatura**

```markdown
# Naming Conventions

## Tópicos Kafka
Formato: `<domain>.<event-kebab>.v<major>`
- domain: `work`, `resource`, `procurement`, `measurement`, `quality`, `identity`, `audit`
- event-kebab: kebab-case descritivo (ex.: `work-order-created`)
- major: versão principal do contrato

Exemplos:
- `work.work-order-created.v1`
- `resource.resource-reserved.v1`
- `measurement.measurement-approved.v1`
- `quality.non-conformance-opened.v1`
- `audit.user-action-logged.v1`

## DLQ (Dead Letter Queue)
Formato: `<domain>.<event-kebab>.v<major>.dlq`
- Retry automático com backoff exponencial
- Máximo 3 tentativas antes de enviar para DLQ
- Retenção de 30 dias para análise

## Schema Registry
- Compatibilidade: BACKWARD (novos campos opcionais)
- Validação: OBRIGATÓRIA para produção
- Versionamento: SemVer para schemas

## Grupos de Consumidores
`<system>-<bounded-context>-<purpose>` (ex.: `obraflow-work-projections`)

## Chaves de Partição
Concatenação estável: `${tenantId}:${aggregateId}`

## Headers (recomendado)
- `x-tenant-id`, `x-correlation-id`, `x-causation-id`, `x-idempotency-key`
```

---

## 3) `versioning-policy.md` — **Política de Evolução**

```markdown
# Versionamento e Compatibilidade

- **Major** na *rota/tópico* (`.v1`, `.v2`) para mudanças **incompatíveis**.
- **Minor/Patch** via evolução **compatível** no JSON Schema:
  - Adições de campos opcionais ✅
  - Novos enum values que consumidores tolerem ✅
  - Remoções/renomeações ⛔ → exigem novo major
  - Mudança de tipo de campo ⛔ → exige novo major
  - Mudança de constraints (min/max) ⛔ → exige novo major
- Período de **depreciação**: manter `v1` e `v2` em paralelo por 6 meses.
- **SemVer** nos arquivos de schema (`$id` com sufixo `#1.2.0`).
- **Validação**: Schema Registry com compatibilidade BACKWARD obrigatória.
- **Migração**: Ferramentas automáticas para migração de consumidores.
- **Documentação**: Changelog obrigatório para mudanças breaking.
```

---

## 4) `security-acl.md` — **Segurança/ACL**

```markdown
# Segurança & ACL (Kafka)

- Autenticação: SASL/SCRAM-SHA-512 + TLS
- Autorização: ACLs por prefixo de tópico (`work.*.v1`) e por `group.id`
- Produção somente por serviços autorizados (ex.: `work-management` para `work.*`)
- Headers com identificadores **não sensíveis** (PII proibido)
- Logs e traces vinculados por `correlationId` (ver Manifesto 1)
```

---

## 5) `retention-dlq-policy.md` — **Retenção, Retries e DLQ**

```markdown
# Retenção, Retries e DLQ

- Retenção padrão: 7 dias (prod), 3 dias (hml)
- **Retries**: consumidor aplica retry com backoff exponencial (máx. 5) + idempotência
- **DLQ**: `<topic>.dlq` para mensagens com falhas não recuperáveis (poison pill) ou esgotado o retry
- **Reprocessamento**: somente via jobs dedicados, com janela temporal e **idempotencyKey**
- **Outbox**: produtores confirmam publicação atômica (Outbox → Kafka)
- **Circuit Breaker**: Abrir após 5 falhas consecutivas, fechar após 30s
- **Dead Letter**: Após 3 tentativas, enviar para DLQ com metadata de erro
- **Monitoring**: Alertas para DLQ com > 10 mensagens em 5min
- **Retention DLQ**: 30 dias para análise forense
- **Compaction**: Tópicos de estado com compactação por chave
```

---

## 6) `schemas/common/envelope.json` — **Envelope padrão**

```json
{
  "$id": "https://obraflow.example/schemas/common/envelope.json#1.0.0",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "EventEnvelope",
  "type": "object",
  "required": ["eventId", "type", "source", "time", "tenantId", "data"],
  "properties": {
    "eventId": { "type": "string", "description": "ULID/UUID v4" },
    "type": { "type": "string", "description": "ex.: work.work-order-created.v1" },
    "source": { "type": "string", "description": "serviço/BC produtor (ex.: work-management)" },
    "time": { "type": "string", "format": "date-time" },
    "tenantId": { "type": "string" },
    "siteId": { "type": "string" },
    "correlationId": { "type": "string" },
    "causationId": { "type": "string" },
    "idempotencyKey": { "type": "string" },
    "specVersion": { "type": "string", "default": "1.0" },
    "schemaRef": { "type": "string", "description": "URL do schema da carga" },
    "data": { "type": "object", "description": "Carga específica do evento" }
  },
  "additionalProperties": false
}
```

---

## 7) **Schemas por domínio** (amostras)

### `schemas/work/WorkOrderCreated.json`

```json
{
  "$id": "https://obraflow.example/schemas/work/WorkOrderCreated.json#1.0.0",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "WorkOrderCreated",
  "type": "object",
  "required": ["woId", "aggregateId", "wbsPath", "title", "plannedWindow"],
  "properties": {
    "woId": { "type": "string" },
    "aggregateId": { "type": "string", "description": "Id do agregado WorkOrder (para partição)" },
    "wbsPath": { "type": "string" },
    "title": { "type": "string" },
    "plannedWindow": {
      "type": "object",
      "required": ["start", "end"],
      "properties": {
        "start": { "type": "string", "format": "date-time" },
        "end": { "type": "string", "format": "date-time" }
      }
    },
    "resources": {
      "type": "object",
      "properties": {
        "crew": {
          "type": "array",
          "items": { "type": "object", "properties": { "skill": { "type": "string" }, "qty": { "type": "number" } }, "required": ["skill","qty"] }
        },
        "equipment": {
          "type": "array",
          "items": { "type": "object", "properties": { "type": { "type": "string" }, "qty": { "type": "number" } }, "required": ["type","qty"] }
        },
        "materials": {
          "type": "array",
          "items": { "type": "object", "properties": { "sku": { "type": "string" }, "qty": { "type": "string" } }, "required": ["sku","qty"] }
        }
      }
    }
  },
  "additionalProperties": false
}
```

### `schemas/resource/ResourceReserved.json`

```json
{
  "$id": "https://obraflow.example/schemas/resource/ResourceReserved.json#1.0.0",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "ResourceReserved",
  "type": "object",
  "required": ["woId", "aggregateId", "reservations", "ttlHours"],
  "properties": {
    "woId": { "type": "string" },
    "aggregateId": { "type": "string" },
    "reservations": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["resourceType", "from", "to", "qty"],
        "properties": {
          "resourceType": { "type": "string", "enum": ["crew", "equipment", "material"] },
          "skill": { "type": "string" },
          "type": { "type": "string" },
          "qty": { "type": "number" },
          "from": { "type": "string", "format": "date-time" },
          "to": { "type": "string", "format": "date-time" }
        }
      }
    },
    "ttlHours": { "type": "integer", "minimum": 1 }
  },
  "additionalProperties": false"
}
```

### `schemas/procurement/MaterialRequisitionSubmitted.json`

```json
{
  "$id": "https://obraflow.example/schemas/procurement/MaterialRequisitionSubmitted.json#1.0.0",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "MaterialRequisitionSubmitted",
  "type": "object",
  "required": ["reqId", "aggregateId", "items", "neededBy"],
  "properties": {
    "reqId": { "type": "string" },
    "aggregateId": { "type": "string", "description": "Agregado Requisition" },
    "items": {
      "type": "array",
      "items": { "type": "object", "required": ["sku", "qty", "uom"], "properties": {
        "sku": { "type": "string" },
        "qty": { "type": "number" },
        "uom": { "type": "string" }
      }}
    },
    "neededBy": { "type": "string", "format": "date-time" },
    "siteId": { "type": "string" }
  },
  "additionalProperties": false
}
```

### `schemas/measurement/MeasurementApproved.json`

```json
{
  "$id": "https://obraflow.example/schemas/measurement/MeasurementApproved.json#1.0.0",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "MeasurementApproved",
  "type": "object",
  "required": ["measurementId", "aggregateId", "periodStart", "periodEnd", "amount"],
  "properties": {
    "measurementId": { "type": "string" },
    "aggregateId": { "type": "string", "description": "Agregado Measurement" },
    "periodStart": { "type": "string", "format": "date-time" },
    "periodEnd": { "type": "string", "format": "date-time" },
    "amount": { "type": "number" },
    "currency": { "type": "string", "default": "BRL" }
  },
  "additionalProperties": false
}
```

### `schemas/quality/NonConformanceOpened.json`

```json
{
  "$id": "https://obraflow.example/schemas/quality/NonConformanceOpened.json#1.0.0",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "NonConformanceOpened",
  "type": "object",
  "required": ["ncrId", "aggregateId", "category", "severity", "detectedAt"],
  "properties": {
    "ncrId": { "type": "string" },
    "aggregateId": { "type": "string", "description": "Agregado NCR" },
    "category": { "type": "string", "enum": ["material", "execucao", "seguranca", "documentacao"] },
    "severity": { "type": "string", "enum": ["low", "medium", "high", "critical"] },
    "detectedAt": { "type": "string", "format": "date-time" },
    "woId": { "type": "string" }
  },
  "additionalProperties": false
}
```

---

## 8) `asyncapi.yml` — **Catálogo consolidado**

```yaml
asyncapi: 2.6.0
info:
  title: ObraFlow Event Catalog
  version: 0.1.0
  description: >
    Catálogo de eventos assíncronos do ObraFlow (DDD + Sagas + Outbox).
defaultContentType: application/json

servers:
  prd:
    url: kafka-prd.obraflow.example:9092
    protocol: kafka-secure
    description: Cluster Kafka (produção)
    security:
      - saslScram: []
  hml:
    url: kafka-hml.obraflow.example:9092
    protocol: kafka-secure
    description: Cluster Kafka (homolog)
    security:
      - saslScram: []

channels:
  work.work-order-created.v1:
    bindings:
      kafka:
        topic: work.work-order-created.v1
        partitions: 24
        replicas: 3
        retentionMs: 604800000 # 7 dias
    subscribe:
      summary: Emissão quando uma OS é criada
      message:
        $ref: '#/components/messages/WorkOrderCreated'
  resource.resource-reserved.v1:
    bindings:
      kafka:
        topic: resource.resource-reserved.v1
        partitions: 24
        replicas: 3
        retentionMs: 604800000
    subscribe:
      summary: Reserva de recursos confirmada (com TTL)
      message:
        $ref: '#/components/messages/ResourceReserved'
  procurement.material-requisition-submitted.v1:
    bindings:
      kafka:
        topic: procurement.material-requisition-submitted.v1
        partitions: 24
        replicas: 3
    subscribe:
      message:
        $ref: '#/components/messages/MaterialRequisitionSubmitted'
  measurement.measurement-approved.v1:
    bindings:
      kafka:
        topic: measurement.measurement-approved.v1
        partitions: 24
        replicas: 3
    subscribe:
      message:
        $ref: '#/components/messages/MeasurementApproved'
  quality.non-conformance-opened.v1:
    bindings:
      kafka:
        topic: quality.non-conformance-opened.v1
        partitions: 24
        replicas: 3
    subscribe:
      message:
        $ref: '#/components/messages/NonConformanceOpened'

components:
  securitySchemes:
    saslScram:
      type: userPassword
      description: SASL/SCRAM-SHA-512
  schemas:
    Envelope:
      $ref: './schemas/common/envelope.json'
    WorkOrderCreatedData:
      $ref: './schemas/work/WorkOrderCreated.json'
    ResourceReservedData:
      $ref: './schemas/resource/ResourceReserved.json'
    MaterialRequisitionSubmittedData:
      $ref: './schemas/procurement/MaterialRequisitionSubmitted.json'
    MeasurementApprovedData:
      $ref: './schemas/measurement/MeasurementApproved.json'
    NonConformanceOpenedData:
      $ref: './schemas/quality/NonConformanceOpened.json'

  messages:
    WorkOrderCreated:
      name: WorkOrderCreated
      contentType: application/json
      payload:
        allOf:
          - $ref: '#/components/schemas/Envelope'
          - type: object
            properties:
              type: { const: "work.work-order-created.v1" }
              data: { $ref: '#/components/schemas/WorkOrderCreatedData' }
      bindings:
        kafka:
          key:
            type: string
            description: "Partition key: ${tenantId}:${data.aggregateId}"
          headers:
            type: object
            properties:
              x-tenant-id: { type: string }
              x-correlation-id: { type: string }
              x-causation-id: { type: string }
              x-idempotency-key: { type: string }

    ResourceReserved:
      name: ResourceReserved
      contentType: application/json
      payload:
        allOf:
          - $ref: '#/components/schemas/Envelope'
          - type: object
            properties:
              type: { const: "resource.resource-reserved.v1" }
              data: { $ref: '#/components/schemas/ResourceReservedData' }
      bindings:
        kafka:
          key: { type: string }

    MaterialRequisitionSubmitted:
      name: MaterialRequisitionSubmitted
      contentType: application/json
      payload:
        allOf:
          - $ref: '#/components/schemas/Envelope'
          - type: object
            properties:
              type: { const: "procurement.material-requisition-submitted.v1" }
              data: { $ref: '#/components/schemas/MaterialRequisitionSubmittedData' }

    MeasurementApproved:
      name: MeasurementApproved
      contentType: application/json
      payload:
        allOf:
          - $ref: '#/components/schemas/Envelope'
          - type: object
            properties:
              type: { const: "measurement.measurement-approved.v1" }
              data: { $ref: '#/components/schemas/MeasurementApprovedData' }

    NonConformanceOpened:
      name: NonConformanceOpened
      contentType: application/json
      payload:
        allOf:
          - $ref: '#/components/schemas/Envelope'
          - type: object
            properties:
              type: { const: "quality.non-conformance-opened.v1" }
              data: { $ref: '#/components/schemas/NonConformanceOpenedData' }
```

---

## 9) **Exemplos de payloads** (`examples/*.json`)

### `examples/work/WorkOrderCreated.example.json`

```json
{
  "eventId": "01J9V9X2K7Z3C7Y7HAB2N3Z2Q8",
  "type": "work.work-order-created.v1",
  "source": "work-management",
  "time": "2025-09-21T12:00:00Z",
  "tenantId": "acme",
  "siteId": "obra-sp-01",
  "correlationId": "co-123",
  "causationId": "ca-123",
  "idempotencyKey": "wo-2025-000123",
  "data": {
    "woId": "WO-2025-000123",
    "aggregateId": "WO-2025-000123",
    "wbsPath": "1.2.3",
    "title": "Alvenaria Bloco A - Pav.2",
    "plannedWindow": { "start": "2025-09-22T07:00:00Z", "end": "2025-09-25T17:00:00Z" },
    "resources": {
      "crew": [{ "skill": "alvenaria", "qty": 6 }],
      "equipment": [{ "type": "betoneira", "qty": 1 }],
      "materials": [{ "sku": "bloco-14", "qty": "5000 un" }]
    }
  }
}
```

*(demais exemplos análogos para `ResourceReserved`, `MaterialRequisitionSubmitted`, `MeasurementApproved`, `NonConformanceOpened`)*

---

## 10) `testing-contracts.md` — **Estratégia de Testes de Contrato (CDC)**

```markdown
# Consumer-Driven Contracts (CDC) — Assíncrono

- **Geradores**: produtores validam schema com `ajv` (Node) / `gojsonschema` (Go) antes de publicar.
- **Validadores**: consumidores testam contra exemplos fixos + contra o **schema** versionado.
- **CI**: pipeline executa
  1) lint de AsyncAPI,
  2) validação de schemas,
  3) *compatibility check* (mudanças são *additive*),
  4) publicação em **Schema Registry** (ou artefatos versionados).
- **Contrato automatizado**: PRs que alteram `schemas/` exigem aprovação de consumidores listados em `CODEOWNERS`.
```

---

## 11) **Exemplos de Produção/Consumo (referenciais)**

> **Node/NestJS (produtor)** — publicação a partir de Outbox (pseudo-código, tipado)

```ts
import { Kafka } from 'kafkajs';
import { randomUUID } from 'node:crypto';

type Envelope<T> = {
  eventId: string; type: string; source: string; time: string;
  tenantId: string; siteId?: string; correlationId?: string; causationId?: string;
  idempotencyKey?: string; specVersion?: string; schemaRef?: string; data: T;
};

type WorkOrderCreated = { woId: string; aggregateId: string; wbsPath: string; title: string;
  plannedWindow: { start: string; end: string };
  resources?: { crew?: {skill:string;qty:number}[]; equipment?: {type:string;qty:number}[]; materials?: {sku:string;qty:string}[] } };

const kafka = new Kafka({ clientId: 'work-mgmt', brokers: [process.env.KAFKA!] });
const producer = kafka.producer();

export async function publishWorkOrderCreated(tenantId: string, payload: WorkOrderCreated, correlationId?: string) {
  const envelope: Envelope<WorkOrderCreated> = {
    eventId: randomUUID(),
    type: 'work.work-order-created.v1',
    source: 'work-management',
    time: new Date().toISOString(),
    tenantId,
    correlationId,
    data: payload
  };
  const key = `${tenantId}:${payload.aggregateId}`;
  await producer.connect();
  await producer.send({
    topic: 'work.work-order-created.v1',
    messages: [{ key, value: JSON.stringify(envelope), headers: {
      'x-tenant-id': tenantId, 'x-correlation-id': correlationId ?? envelope.eventId,
      'x-idempotency-key': payload.woId
    }}]
  });
}
```

> **Go/Watermill (consumidor)** — projeção de leitura (pseudo-código)

```go
type Envelope[T any] struct {
  EventID string `json:"eventId"`
  Type string `json:"type"`
  Source string `json:"source"`
  Time time.Time `json:"time"`
  TenantID string `json:"tenantId"`
  SiteID *string `json:"siteId,omitempty"`
  CorrelationID *string `json:"correlationId,omitempty"`
  CausationID *string `json:"causationId,omitempty"`
  IdempotencyKey *string `json:"idempotencyKey,omitempty"`
  Data T `json:"data"`
}

type WorkOrderCreated struct {
  WoID string `json:"woId"`
  AggregateID string `json:"aggregateId"`
  WbsPath string `json:"wbsPath"`
  Title string `json:"title"`
  PlannedWindow struct {
    Start time.Time `json:"start"`
    End   time.Time `json:"end"`
  } `json:"plannedWindow"`
}

func handleWorkOrderCreated(msg *message.Message) error {
  var env Envelope[WorkOrderCreated]
  if err := json.Unmarshal(msg.Payload, &env); err != nil { return err }
  // idempotência: upsert por (tenantId, aggregateId)
  return upsertWorkOrderProjection(env.TenantID, env.Data.AggregateID, env.Data)
}
```

---

## 12) Observabilidade e SLOs (ponte com Manifesto 1)

* **Campos de correlação** no envelope + **headers Kafka** → **traces/métricas/logs** com `correlation_id`, `tenant_id` e `site_id`.
* **Métricas de filas/outbox** (profundidade, lag) entram no painel SLO de “Sync Mobile” e “OS → Medição”.
* **DLQ** monitorado com alertas (taxa > 0.1% → *page*).

---

### Pronto. Deseja que eu **prossiga para o Manifesto 3 — *Threat Model + DPIA (LGPD)*** ou prefere ajustar algum detalhe deste catálogo (ex.: nomes de eventos, chaves de partição, retenção, ou política de versão)?
