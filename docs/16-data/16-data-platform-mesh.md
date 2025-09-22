# Manifesto 13 — **Data Platform & Mesh Operacional**

*(Camadas, contratos de dados, domínios (mesh), qualidade, catálogo, privacidade, SLAs e exemplos executáveis)*

Este manifesto de plataforma de dados foi **integrado com os padrões técnicos** definidos no plano de ação do monorepo, garantindo alinhamento entre arquitetura, desenvolvimento e operações. Estabelece a **plataforma de dados operacional** do ObraFlow e o **modelo de Data Mesh**, cobrindo: **arquitetura de camadas (medallion)**, **contratos de dados** (esquemas versionados e políticas), **produtos de dados por domínio**, **ingestão CDC/streaming/batch**, **qualidade (tests/SLAs)**, **catálogo e linhagem**, **governança/LGPD**, **observabilidade**, **padrões de modelagem** (Lakehouse/SQL/dbt) e **exemplos prontos**.

---

## 📁 Estrutura de diretórios (monorepo de dados)

```
data-platform/
  README.md
  architecture/
    platform-high-level.md
    medallion-layers.md
    data-mesh-model.md
  governance/
    data-contracts/
      README.md
      schemas/
        kafka/
          obraflow.work.v1.WorkOrderCreated.avsc
          obraflow.measure.v1.ProductionReported.avsc
        api/
          rest-openapi-extract.json
        warehouse/
          gold.work_orders.schema.yaml
      versioning-policy.md
      breaking-change-procedure.md
    privacy-lgpd/
      data-classification.md
      retention-lifecycle.md
      rls-policies.sql
      dpiA-template.md
    access/
      rbac-model.md
      row-column-masking.sql
      token-scoped-policies.md
  ingestion/
    streaming/
      kafka-topics.yaml
      debezium-connectors/
        postgres-workorders.json
      flink-jobs/
        workorders-enricher.sql
    batch/
      airflow-dags/
        dag_daily_extract.py
      argo-workflows/
        ingest-s3.yaml
  lakehouse/
    storage-layout.md
    iceberg/
      tables/
        bronze/
          work_orders/
        silver/
          work_orders_clean/
        gold/
          work_kpis_daily/
      maintenance/
        optimize.compact.yaml
  transformations/
    dbt/
      dbt_project.yml
      models/
        bronze/
          br_work_orders.sql
        silver/
          sv_work_orders.sql
          sv_production_events.sql
        gold/
          g_work_kpis_daily.sql
      tests/
        schema.yml
        expectations.yml
  quality-observability/
    expectations/
      great_expectations.yml
    soda/
      checks.yaml
    alerts/
      prometheus-rules.yaml
    lineage/
      openlineage-config.yaml
  catalog/
    openmetadata/
      ingestion.yml
    datahub/
      metadata-ingestion.yml
  products/
    work/
      README.md
      product.yaml
      slas.md
      interfaces/
        sql/
          views.sql
        api/
          graphql.schema.graphql
    supply/
      ...
  ops/
    runbooks/
      late-arriving-data.md
      schema-drift.md
      backfill-playbook.md
```

---

## 1) Arquitetura — visão e princípios

### 1.1 Plataforma (alto nível) — `architecture/platform-high-level.md`

* **Lakehouse** com **Iceberg** (tabelas ACID no data lake), **compute desacoplado** (Spark/Flink/Trino/BigQuery/Snowflake opcional), **catálogo central** (Glue/Hive + OpenMetadata/DataHub).
* **Streaming-first** para eventos operacionais (Kafka) e **CDC** (Debezium) para bases transacionais.
* **Medallion**: **Bronze (raw/append)** → **Silver (limpo/PK/FK/SCD)** → **Gold (métricas/KPIs/serving)**.
* **Data Mesh**: domínios **work**, **measurement**, **supply**, **finance**, **identity**, cada qual produz **data products** com **contratos e SLAs**.

### 1.2 Data Mesh — `architecture/data-mesh-model.md`

* **Produto de dados** = *dataset + contrato + dono + SLAs + políticas de acesso + linhagem + documentação*.
* **Ownership** por domínio (ex.: *Work Domain Team* mantém `gold.work_kpis_daily`).
* **Interoperabilidade** por **contratos versão N** (Avro/Protobuf/DDL/dbt schema).
* **Plataforma** provê **pavimentação** (infra, catálogos, políticas, observabilidade).

---

## 2) Contratos de dados (Data Contracts)

### 2.1 Política — `governance/data-contracts/versioning-policy.md`

* **SemVer** para **esquemas**: *breaking* → major (`.v2`); *additive compatível* → minor.
* **Eventos** em Kafka: *topic name* `domain.entity.vN` (alinhado ao Manifesto 2).
* **Warehouse**: alterações *breaking* exigem **tabela/valor** novos ou `gold_v2`.
* **Gate CI**: PR falha se schema quebrar compatibilidade (ver *quality-observability*).

### 2.2 Exemplo Avro (evento) — `governance/data-contracts/schemas/kafka/obraflow.work.v1.WorkOrderCreated.avsc`

```json
{
  "type": "record",
  "name": "WorkOrderCreated",
  "namespace": "obraflow.work.v1",
  "doc": "Evento de criação de OS",
  "fields": [
    {"name": "woId", "type": "string"},
    {"name": "title", "type": "string"},
    {"name": "wbsPath", "type": ["null","string"], "default": null},
    {"name": "plannedStart", "type": {"type":"long","logicalType":"timestamp-millis"}},
    {"name": "plannedEnd", "type": {"type":"long","logicalType":"timestamp-millis"}},
    {"name": "tenantId", "type": "string"},
    {"name": "siteId", "type": ["null","string"], "default": null},
    {"name": "idempotencyKey", "type":"string"}
  ]
}
```

### 2.3 Contrato Gold (warehouse) — `governance/data-contracts/warehouse/gold.work_orders.schema.yaml`

```yaml
table: gold.work_orders
owner: domain:work
description: "Fato de ordens de serviço com atributos de planejamento e execução"
schema:
  - name: wo_id           ; type: STRING ; constraints: [pk, not_null]
  - name: title           ; type: STRING ; constraints: [not_null]
  - name: status          ; type: STRING ; valid: [SCHEDULED, IN_PROGRESS, BLOCKED, DONE, CANCELLED]
  - name: planned_start   ; type: TIMESTAMP ; tz: UTC
  - name: planned_end     ; type: TIMESTAMP ; tz: UTC
  - name: actual_start    ; type: TIMESTAMP? ; tz: UTC
  - name: actual_end      ; type: TIMESTAMP? ; tz: UTC
  - name: tenant_id       ; type: STRING ; constraints: [not_null]
  - name: site_id         ; type: STRING?
  - name: wbs_path        ; type: STRING?
  - name: row_eff_start   ; type: TIMESTAMP ; desc: "SCD2 effective from"
  - name: row_eff_end     ; type: TIMESTAMP ; desc: "SCD2 effective to"
  - name: is_current      ; type: BOOLEAN ; default: true
sla:
  freshness: "<= 15m (prod)"     # atraso máximo admissível
  completeness: ">= 99.5% rows/dia"
  quality_checks: ["not_null", "valid_values", "fk_integrity", "duplicates<0.1%"]
pii:
  classification: "low"          # sem PII direta neste produto
access:
  rls: ["tenant_id"]
```

---

## 3) Ingestão

### 3.1 Streaming (Kafka) — `ingestion/streaming/kafka-topics.yaml`

```yaml
topics:
  - name: obraflow.work.v1.work-order-created
    partitions: 12
    replication: 3
    retention: 7d
    schema: governance/data-contracts/schemas/kafka/obraflow.work.v1.WorkOrderCreated.avsc
  - name: obraflow.measure.v1.production-reported
    partitions: 12
    replication: 3
    retention: 14d
```

**CDC Debezium** (Postgres → Kafka) — `ingestion/streaming/debezium-connectors/postgres-workorders.json`

```json
{
  "name": "pg-workorders",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "pg",
    "database.port": "5432",
    "database.user": "replica",
    "database.password": "****",
    "database.dbname": "obraflow",
    "slot.name": "debezium_work",
    "publication.autocreate.mode": "filtered",
    "table.include.list": "public.work_orders",
    "tombstones.on.delete": "false",
    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.add.fields": "op,ts_ms"
  }
}
```

### 3.2 Streaming SQL (Flink) — `ingestion/streaming/flink-jobs/workorders-enricher.sql`

```sql
-- Enriquecimento e roteamento de WorkOrderCreated para bronze Iceberg
CREATE TABLE wo_created_kafka ( ... ) WITH (...);           -- usa formato avro+schema registry
CREATE TABLE bronze_work_orders WITH (
  'connector'='iceberg',
  'catalog'='glue',
  'database'='bronze',
  'table'='work_orders'
) LIKE wo_created_kafka INCLUDING ALL;

INSERT INTO bronze_work_orders
SELECT * FROM wo_created_kafka;
```

### 3.3 Batch (Airflow/Argo) — `ingestion/batch/airflow-dags/dag_daily_extract.py`

```python
from airflow import DAG
from airflow.providers.amazon.aws.transfers.s3_to_s3 import S3CopyObjectOperator
from datetime import datetime

with DAG("daily_extract_rest", start_date=datetime(2025,9,1), schedule="@daily", catchup=False) as dag:
    S3CopyObjectOperator(
        task_id="copy_rest_to_bronze",
        source_bucket_key="raw/api/work-orders/{{ ds }}/extract.json",
        dest_bucket_key="lake/bronze/work_orders/date={{ ds }}/extract.json",
        source_bucket_name="obraflow-raw",
        dest_bucket_name="obraflow-lake"
    )
```

---

## 4) Lakehouse (Iceberg) e layout — `lakehouse/storage-layout.md`

* Padrão de **particionamento**: por **tenant\_id** e **date** (UTC) em bronze/silver; em gold, por **date** e **site\_id** quando otimiza leitura.
* **Compaction/Optimize** diário; **vacuum** de snapshots por **retention**.
* **Schema evolution** apenas *additive* em silver; *breaking* cria nova tabela `*_v2`.

Exemplo de **manutenção** — `lakehouse/iceberg/maintenance/optimize.compact.yaml`

```yaml
schedule: "0 2 * * *"
tables:
  - bronze.work_orders
  - silver.work_orders_clean
  - gold.work_kpis_daily
actions:
  - rewrite-manifests
  - rewrite-data-files:
      target-file-size-bytes: 134217728
```

---

## 5) Transformações (dbt)

### 5.1 Configuração — `transformations/dbt/dbt_project.yml`

```yaml
name: "obraflow_dwh"
version: "1.0.0"
profile: "lakehouse_trino"   # ou bigquery/snowflake
models:
  obraflow_dwh:
    bronze:
      +materialized: incremental
      +on_schema_change: ignore
    silver:
      +materialized: incremental
      +on_schema_change: append_new_columns
    gold:
      +materialized: table
```

### 5.2 Bronze → Silver — `transformations/dbt/models/silver/sv_work_orders.sql`

```sql
{{ config(
  materialized='incremental',
  unique_key='wo_id',
  incremental_strategy='merge'
) }}

WITH src AS (
  SELECT
    cast(data:woId as varchar)        AS wo_id,
    data:title::varchar               AS title,
    data:wbsPath::varchar             AS wbs_path,
    to_timestamp(data:plannedStart/1000) AS planned_start,
    to_timestamp(data:plannedEnd/1000)   AS planned_end,
    data:tenantId::varchar            AS tenant_id,
    data:siteId::varchar              AS site_id,
    _ingest_ts                        AS ingest_ts
  FROM {{ ref('br_work_orders') }}
)
, dedup AS (
  SELECT *,
    row_number() over (partition by wo_id order by ingest_ts desc) as rn
  FROM src
)
SELECT
  wo_id, title, wbs_path, planned_start, planned_end,
  tenant_id, site_id,
  current_timestamp as row_eff_start,
  null::timestamp as row_eff_end,
  true as is_current
FROM dedup
WHERE rn = 1

{% if is_incremental() %}
  -- fecha SCD2 de registros antigos
  UNION ALL
  SELECT old.wo_id, old.title, old.wbs_path, old.planned_start, old.planned_end,
         old.tenant_id, old.site_id,
         old.row_eff_start,
         current_timestamp as row_eff_end,
         false as is_current
  FROM {{ this }} old
  JOIN (SELECT wo_id FROM dedup WHERE rn = 1) ch USING (wo_id)
  WHERE old.is_current = true
{% endif %}
```

### 5.3 Gold — KPIs — `transformations/dbt/models/gold/g_work_kpis_daily.sql`

```sql
{{ config(materialized='table') }}

WITH base AS (
  SELECT tenant_id, site_id, date_trunc('day', planned_start) AS day, count(*) AS os_count
  FROM {{ ref('sv_work_orders') }}
  WHERE is_current = true
  GROUP BY 1,2,3
)
SELECT
  tenant_id, site_id, day,
  os_count,
  os_count / NULLIF(sum(os_count) over (partition by tenant_id order by day rows between 6 preceding and current row),0) as os_7d_ratio
FROM base;
```

### 5.4 Testes (dbt + expectativas) — `transformations/dbt/tests/schema.yml`

```yaml
version: 2
models:
  - name: sv_work_orders
    columns:
      - name: wo_id
        tests: [not_null, unique]
      - name: planned_start
        tests: [not_null]
      - name: tenant_id
        tests: [not_null]
  - name: g_work_kpis_daily
    columns:
      - name: day
        tests: [not_null]
```

---

## 6) Qualidade e Observabilidade de Dados

### 6.1 Great Expectations — `quality-observability/expectations/great_expectations.yml`

```yaml
datasources:
  lakehouse:
    class_name: Datasource
    execution_engine: { class_name: SparkDFExecutionEngine }
    data_connectors:
      default_runtime_data_connector_name: { class_name: RuntimeDataConnector }
suites:
  - name: silver_work_orders_suite
    expectations:
      - expect_column_values_to_not_be_null: { column: wo_id }
      - expect_column_values_to_be_between:
          column: planned_start
          min_value: "2020-01-01T00:00:00Z"
          strict_min: true
```

### 6.2 Soda — `quality-observability/soda/checks.yaml`

```yaml
checks for sv_work_orders:
  - missing_count(wo_id) = 0
  - invalid_percentage(status) < 0.5 % invalid values: ["UNKNOWN"]
  - schema:
      warn:
        when required column missing:
          - wo_id
          - title
```

### 6.3 Alertas — `quality-observability/alerts/prometheus-rules.yaml`

```yaml
groups:
  - name: data-quality
    rules:
      - alert: DataFreshnessBreach
        expr: (time() - dataset_freshness_seconds{dataset="gold.work_kpis_daily"}) > 900
        for: 10m
        labels: { severity: ticket }
        annotations: { summary: "Freshness > 15m em gold.work_kpis_daily" }
      - alert: DataQualityFailure
        expr: data_quality_checks_failed_total > 0
        for: 5m
        labels: { severity: ticket }
```

### 6.4 Linhagem — `quality-observability/lineage/openlineage-config.yaml`

```yaml
transport:
  type: http
  url: http://openlineage:8080
facets:
  enabled: [schema, ownership, dataQualityMetrics]
```

---

## 7) Catálogo de Dados (documentação & descoberta)

* **OpenMetadata** ou **DataHub** para catálogo, *glossary*, donos, SLAs e linhagem automática.

`catalog/openmetadata/ingestion.yml`

```yaml
source:
  type: trino
  serviceName: obraflow-trino
  serviceConnection:
    config:
      hostPort: trino:8080
sink:
  type: metadata-rest
workflowConfig:
  openMetadataServerConfig: { hostPort: http://openmetadata:8585 }
```

---

## 8) Governança, Privacidade & Acesso

### 8.1 Classificação — `governance/privacy-lgpd/data-classification.md`

* **PII Alta**: documentos pessoais, biometria (não ingestão sem DPIA e DLP).
* **PII Média**: e-mails/celulares de colaboradores.
* **Baixa/None**: OS, medições agregadas.
* **Regra**: datasets `bronze.*` podem conter PII; **silver/gold** devem **pseudonimizar** ou remover.

### 8.2 Retenção — `governance/privacy-lgpd/retention-lifecycle.md`

* **Bronze**: 90 dias (raw); **Silver**: 365 dias; **Gold**: conforme uso de negócio (tipicamente 730 dias).
* **Expurgo** automatizado por *lifecycle* (S3/ICEBERG expire snapshots).
* **Right to be forgotten**: localizar por `natural_key_hash` e remover/pseudonimizar.

### 8.3 RLS/mascaramento — `governance/privacy-lgpd/rls-policies.sql`

```sql
-- Exemplo: Trino/Presto ou engine com policies
-- Permite acesso apenas ao tenant_id do usuário
CREATE POLICY rls_tenant ON gold.work_orders
USING (tenant_id = current_user_tenant());
```

`governance/access/row-column-masking.sql`

```sql
-- Masking de colunas sensíveis
SELECT
  CASE WHEN has_masking_role() THEN email ELSE 'REDACTED' END AS email_masked
FROM gold.user_contacts;
```

---

## 9) Produtos de Dados (Data Products)

### 9.1 Exemplo — `products/work/product.yaml`

```yaml
name: work-kpis
domain: work
owner: team-work@obraflow
description: "KPIs diários de execução e planejamento por obra"
outputs:
  - type: table
    ref: gold.work_kpis_daily
    interface:
      sql:
        views:
          - name: vw_work_productivity_7d
            definition: "SELECT tenant_id, site_id, day, os_7d_ratio FROM gold.work_kpis_daily"
  - type: api
    ref: graphql:/workKpisDaily
sla:
  freshness: "<= 15m"
  availability: "99.9%"
  quality: "sem nulos em chaves, 0% duplicados por (tenant,site,day)"
contracts:
  - governance/data-contracts/warehouse/gold.work_orders.schema.yaml
observability:
  dashboards:
    - grafana: "Data Product — Work KPIs"
security:
  rls: tenant_id
  pii: none
```

`products/work/interfaces/sql/views.sql`

```sql
CREATE OR REPLACE VIEW gold.vw_work_productivity_7d AS
SELECT tenant_id, site_id, day, os_7d_ratio FROM gold.work_kpis_daily;
```

`products/work/interfaces/api/graphql.schema.graphql`

```graphql
type WorkKpiDaily {
  tenantId: ID!
  siteId: ID!
  day: String!
  osCount: Int!
  os7dRatio: Float
}
type Query {
  workKpisDaily(tenantId: ID!, siteId: ID!, from: String!, to: String!): [WorkKpiDaily!]!
}
```

`products/work/slas.md`

* **Freshness** ≤ 15 min; **Erro** < 0.5% linhas inválidas; **Disponibilidade** 99,9% (consulta).
* **Plano de contingência**: *graceful degradation* para última partição válida.

---

## 10) Runbooks operacionais (dados)

* `late-arriving-data.md`: lidar com atraso (reprocess incremental + marcação *late*).
* `schema-drift.md`: detectar drift (Soda/GE), abrir *freeze* do contrato, acionar domínio.
* `backfill-playbook.md`: *backfill* com partições e **idempotência** (escrever em **Silver temp** → validar → *swap*).

---

## 11) Observabilidade ponta a ponta

* **Métricas**: *dataset\_freshness\_seconds*, *rows\_ingested\_total*, *dq\_checks\_failed\_total*, *bytes\_scanned* por consulta, *cost\_estimated\_r\$* (integra com FinOps — Manif. 11).
* **Logs**: *job\_id*, *dataset*, *partition*, *tenant*, *correlation\_id*.
* **Traces**: OpenLineage → DataHub/OpenMetadata (linhagem).

---

## 12) Integrações com Manifestos 1–12

* **Manif. 1 (SLO/NFR)**: SLAs de *freshness/quality* mapeados; alertas integram *freeze* de release (Manif. 8).
* **Manif. 2 (Eventos)**: tópicos `.vN` como **fonte primária** de bronze; CDC compatível.
* **Manif. 3 (Segurança/LGPD)**: classificação/retention/mascaramento; DPIA para datasets sensíveis.
* **Manif. 4 (Observabilidade)**: métricas e OpenLineage instrumentados.
* **Manif. 5 (API Gov)**: contratos REST/GraphQL exportados para `api/` (fonte de verdade).
* **Manif. 6 (Infra/GitOps)**: ArgoCD orquestra *ingestion/transform*; policies e quotas por namespace.
* **Manif. 7 (Testes)**: data tests (dbt/GE/Soda) no pipeline de CI; CDC/Pact para esquemas.
* **Manif. 8 (Release)**: mudanças *breaking* exigem major e CAB leve.
* **Manif. 9 (Incidentes)**: runbooks de *schema drift* e *late data*.
* **Manif. 10 (DR/BCP)**: *retention/backup* e restore parcial por partição.
* **Manif. 11 (FinOps)**: *bytes scanned* e *cost per query*; otimizações via particionamento/iceberg optimize.
* **Manif. 12 (AI/ML Ops)**: RAG indexa **gold/silver**; *feature store* consome **silver**; catálogos sincronizados.

## 12.1) Integração com Padrões do Monorepo

### Estrutura de Dados Aplicada
```
obraflow/
├── libs/
│   ├── ts/data-contracts/        # Contratos TypeScript
│   ├── ts/data-quality/          # Validação e testes
│   └── go/pkg/data/              # Contratos Go
├── tools/
│   ├── generators/data/          # Scaffolds de produtos de dados
│   └── scripts/data/             # Scripts de migração
└── .github/workflows/
    ├── data-quality.yml          # Testes de qualidade
    └── data-governance.yml       # Auditoria de governança
```

### Padrões Técnicos Integrados
- **DDD**: Produtos de dados por domínio (Planning, Work-Management, etc.)
- **CQRS+EDA**: Separação entre comandos e consultas de dados
- **Clean Architecture**: Camadas de bronze/silver/gold
- **Multi-tenant**: Segmentação por tenant/obra nos contratos
- **Observabilidade**: Métricas de qualidade e linhagem de dados

---

## 13) Definition of Ready / Done (Data Platform)

**Ready**

* Catálogo ativo (OpenMetadata/DataHub) com **domínios** e **owners**.
* Iceberg/Tables criadas (bronze/silver/gold) e ingestão inicial configurada.
* Políticas LGPD/retention e RLS definidas.

**Done**

* **3** produtos de dados iniciais publicados (`work-kpis`, `supply-forecast`, `ops-observability`).
* **SLAs** monitorados (freshness/quality) com alertas.
* **Testes** (dbt + GE/Soda) integrados ao CI/CD.
* **Linhagem** visível ponta-a-ponta.
* **Backfill** e **schema drift** com runbooks testados.

---

### Próximos passos sugeridos

1. Publicar o **primeiro lote** de produtos (`work-kpis`) com SLAs e testes.
2. Ativar ingestão **CDC** de `work_orders` e **streaming** para bronze.
3. Instrumentar **freshness** e **quality checks** nos painéis de Operações/FinOps.
4. Conectar **AI Gateway** (Manif. 12) ao **gold/silver** via views de leitura com RLS.

Se estiver de acordo, posso seguir com o **Manifesto 14 — *Analytics & BI (Métricas, Semântica, Dashboards executivos, Governança de Métricas)***, ou ajusto algum ponto desta plataforma de dados/data mesh.
