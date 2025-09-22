# Manifesto 14 — **Analytics & BI**

*(Métricas, Camada Semântica, Dashboards Executivos, Governança de Métricas, Performance & Segurança)*

Este pacote estabelece a **plataforma de Analytics & BI** do ObraFlow sobre a base do **Manifesto 13 (Data Platform & Mesh)** e integra **FinOps (Manif. 11)**, **SLOs (Manif. 1/4)** e **AI/ML (Manif. 12)**. Entregamos: **catálogo de métricas**, **camada semântica unificada**, **modelos de dados analíticos**, **dashboards executivos e operacionais**, **testes/validação**, **políticas de acesso (RLS/CLS)** e **boas práticas de desempenho**.

---

## 📁 Estrutura de diretórios (monorepo de BI)

```
analytics-bi/
  README.md
  metrics-catalog/
    glossary.md
    ownership.yaml
    metrics.yaml
    dimensions.yaml
    slos.yaml
    tests/
      metrics-tests.yml
  semantic-layer/
    dbt-metrics/
      schema.yml
      metrics.yml
    lightdash/
      lightdash.yml
    looker/
      obraflow.model.lkml
      views/
        work_orders.view.lkml
        finops.view.lkml
    dremio-semantic/   # opcional (Trino/Superset/Metabase usam SQL direto)
      semantic.yaml
  dashboards/
    exec/
      overview.json     # Grafana/Looker/Metabase spec
      kpi-definitions.md
    operations/
      work-execution.json
      mobile-sync.json
    finops/
      unit-economics.json
    supply/
      materials-forecast.json
  governance/
    metric-versioning.md
    change-process.md
    access-policies.md
    rls-examples.sql
  performance/
    caching.md
    aggregates/
      rollups.sql
      materialized_views.sql
    query-guides.md
  automation/
    ci-validate-metrics.yml
    alerting-rules.yaml
    data-quality-to-metric-bridge.md
```

---

## 1) **Catálogo de Métricas (Single Source of Truth)**

### 1.1 Glossário — `metrics-catalog/glossary.md`

* **OS (Ordem de Serviço)**: unidade de trabalho planejada/executada.
* **Apontamento**: registro de execução/produção.
* **Obra (site)**: local físico; *tenant* pode conter múltiplas obras.
* **R\$/OS**: custo total atribuído ÷ OS concluídas no período (ver Manif. 11).

### 1.2 Propriedade — `metrics-catalog/ownership.yaml`

```yaml
owners:
  work:
    team: work-domain
    contacts: [work@obraflow]
  finops:
    team: finops
    contacts: [finops@obraflow]
  ops:
    team: sre
    contacts: [sre@obraflow]
```

### 1.3 Métricas — `metrics-catalog/metrics.yaml`

```yaml
metrics:
  - name: os_concluidas
    owner: work
    description: "Quantidade de OS com status DONE no período"
    type: counter
    grain: day
    source: gold.work_kpis_daily
    expr: "sum(os_count_done)"
    dimensions: [tenant_id, site_id, day]
    validity:
      freshness: "<= 15m"
      dq_checks: ["not_null(os_count_done)", "os_count_done >= 0"]
  - name: lead_time_os
    owner: work
    description: "Tempo médio (dias) do planned_start ao actual_end"
    type: average
    grain: day
    source: silver.work_orders_clean
    expr: "avg(date_diff('day', planned_start, actual_end))"
    dimensions: [tenant_id, site_id, wbs_path]
  - name: custo_por_os
    owner: finops
    description: "Custo total (compute+storage+dados gerenciados) / OS concluídas"
    type: ratio
    grain: day
    numerator:
      source: finops.daily_cost_by_center
      expr: "sum(cost_r$)"
    denominator:
      ref_metric: os_concluidas
    dimensions: [tenant_id, day]
    constraints:
      note: "Excluir tenants de teste e ambientes != prd"
  - name: taxa_retrabalho
    owner: work
    description: "% de OS reabertas em <= 7 dias após DONE"
    type: ratio
    grain: week
    numerator:
      expr: "count_if(status_transition='REOPENED' and days_since_done<=7)"
      source: gold.work_status_transitions
    denominator:
      expr: "count_if(status_transition='DONE')"
      source: gold.work_status_transitions
  - name: disponibilidade_api
    owner: ops
    description: "Disponibilidade p/ BFF (1 - erro5xx_rate)"
    type: gauge
    grain: 5m
    source: observability.prom
    expr: "1 - (sum(rate(http_requests_total{status=~'5..',env='prd'}[5m])) / sum(rate(http_requests_total{env='prd'}[5m])))"
```

### 1.4 Dimensões — `metrics-catalog/dimensions.yaml`

```yaml
dimensions:
  - name: tenant_id
    type: string
    rls: "tenant_id = current_user_tenant()"
  - name: site_id
    type: string
  - name: day
    type: date
  - name: wbs_path
    type: string
surrogates:
  - name: calendar
    keys: [day]
    attrs: [iso_week, month, quarter, year, is_holiday]
```

### 1.5 SLOs (exposição em BI) — `metrics-catalog/slos.yaml`

```yaml
slos:
  - name: api_latency_p95
    target: "<= 300ms"
    source: observability.prom
    expr: "histogram_quantile(0.95,sum by (le)(rate(http_server_duration_seconds_bucket{env='prd'}[5m])))"
    alert: "ver Manifesto 4/7/8"
```

---

## 2) **Camada Semântica**

### 2.1 **dbt-metrics (OSS)** — `semantic-layer/dbt-metrics/metrics.yml`

```yaml
version: 2
metrics:
  - name: os_concluidas
    label: "OS Concluídas"
    model: ref('g_work_kpis_daily')
    calculation_method: sum
    expression: os_count
    timestamp: day
    time_grains: [day, week, month]
    dimensions: [tenant_id, site_id]
  - name: custo_por_os
    label: "R$/OS"
    calculation_method: ratio
    numerator:
      expr: sum(cost_r$)
      model: ref('finops_daily_cost')
    denominator:
      metric: os_concluidas
    timestamp: day
    time_grains: [day, month]
    dimensions: [tenant_id]
```

### 2.2 **Looker (LookML)** — `semantic-layer/looker/obraflow.model.lkml`

```lkml
connection: "trino_prod"
include: "views/*.view.lkml"

explore: work_orders {
  label: "Work — OS"
  joins: [finops] { type: left_outer; sql_on: ${work_orders.tenant_id} = ${finops.tenant_id} AND ${work_orders.day} = ${finops.day};; }
}
```

`views/work_orders.view.lkml` (trecho)

```lkml
view: work_orders {
  sql_table_name: gold_work_kpis_daily ;;
  dimension_group: day { type: time; timeframes: [date, week, month, quarter, year]; sql: ${TABLE}.day ;; }
  dimension: tenant_id { primary_key: yes; sql: ${TABLE}.tenant_id ;; }
  measure: os_concluidas { type: sum; sql: ${TABLE}.os_count ;; }
  measure: lead_time_os { type: average; sql: datediff('day', ${TABLE}.planned_start, ${TABLE}.actual_end) ;; }
}
```

### 2.3 **Lightdash** — `semantic-layer/lightdash/lightdash.yml`

```yaml
project: obraflow
dbt_target: prod
metrics:
  - name: os_concluidas
    model: ref('g_work_kpis_daily')
    label: "OS Concluídas"
    type: sum
    sql: os_count
  - name: custo_por_os
    label: "R$/OS"
    type: number
    sql: "{{ metric('finops_total_cost') }} / nullif({{ metric('os_concluidas') }},0)"
access:
  rls:
    - dimension: tenant_id
      filter: "{{ user.attributes.tenant_id }}"
```

---

## 3) **Dashboards**

### 3.1 Executivo — `dashboards/exec/overview.json` (layout e KPIs)

* **Header**: filtros (período, tenant, obra), badges de **SLO** (latência, disponibilidade).
* **KPIs**: OS concluídas, Lead Time, R\$/OS, Taxa de Retrabalho, Consumo de Materiais previsto vs real.
* **Série temporal**: **R\$/OS** (MTD vs orçamento) e **OS concl. por semana** (ritmo).
* **Pareto**: top 10 obras por custo e por atraso.
* **Drill**: clique em obra → dashboard operacional.

*(exemplo de target PromQL/SQL inline no spec; manter compatível com ferramenta escolhida)*

### 3.2 Operacional — `dashboards/operations/work-execution.json`

* **Fluxo**: *S-curve* planejado vs realizado (OS).
* **Bottlenecks**: WBS com maior lead time e maior bloqueio.
* **Qualidade**: taxa de retrabalho por equipe/turno.

### 3.3 FinOps — `dashboards/finops/unit-economics.json`

* **Custo diário por cost\_center**; **R\$/OS** com intervalos; **anomalias** (regra Manif. 11).
* **Drill**: serviço → workload → *namespace* (labels de custo do Manif. 6).

### 3.4 Supply — `dashboards/supply/materials-forecast.json`

* **Previsão** (P50/P90) vs consumo real por SKU; **alerta** de ruptura (estoque\<previsão 2 semanas).

---

## 4) **Governança de Métricas**

### 4.1 Versionamento — `governance/metric-versioning.md`

* **SemVer** por métrica: *breaking* (mudança de fórmula/escopo) → nova `metric@v2`.
* **ADR de métrica** obrigatório para alterações significativas (justificativa, impacto).
* **Backfill**: recalcular períodos históricos quando aplicável, com *flag* `recalculated_at`.

### 4.2 Processo de mudança — `governance/change-process.md`

1. Abrir **issue** com proposta → revisão com **owner** do domínio.
2. **Testes** (ver §5) e validação de *sample queries* + comparativo antes/depois.
3. Merge → *broadcast* no catálogo e **changelog de métricas**.

### 4.3 Acesso e Segurança — `governance/access-policies.md`

* **RLS por tenant** em views analíticas (`security_invoker` quando a engine suportar).
* **CLS/Masking** para colunas sensíveis (ver Manif. 13).
* Perfis: **Executivo (read-only high level)**, **Gestor de Obra (scoped por site/tenant)**, **Analista (self-service)**, **Engenharia (dados técnicos)**.

`governance/rls-examples.sql`

```sql
CREATE VIEW gold.vw_work_kpis_daily_rls AS
SELECT * FROM gold.work_kpis_daily
WHERE tenant_id = current_user_tenant();
```

---

## 5) **Qualidade, Testes e Alertas**

### 5.1 Testes de métricas — `metrics-catalog/tests/metrics-tests.yml`

```yaml
tests:
  - metric: os_concluidas
    checks:
      - "os_concluidas(day=today) >= 0"
      - "freshness <= 15m"
  - metric: custo_por_os
    checks:
      - "custo_por_os >= 0"
      - "custo_por_os < 10 * p50(custo_por_os, last_30d)"   # anomalia grosseira
```

### 5.2 CI — `automation/ci-validate-metrics.yml`

```yaml
name: Validate Metrics
on: [pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: dbt compile & test
        run: |
          dbt deps && dbt compile && dbt test --select state:modified+
      - name: metrics lints
        run: node scripts/lint-metrics.js
```

### 5.3 Alertas — `automation/alerting-rules.yaml` (integra com Grafana/Prometheus)

```yaml
groups:
  - name: analytics
    rules:
      - alert: MetricFreshnessBreach
        expr: (time() - metric_freshness_seconds{metric="os_concluidas"}) > 900
        for: 10m
        labels: { severity: ticket }
      - alert: UnitEconomicsAnomaly
        expr: custo_por_os > (1.5 * avg_over_time(custo_por_os[7d]))
        for: 60m
        labels: { severity: ticket }
```

---

## 6) **Modelagem & Performance**

### 6.1 Tabelas de agregação e *rollups* — `performance/aggregates/rollups.sql`

```sql
-- Rollup diário agregado por tenant/site
CREATE TABLE gold_agg.work_os_daily
WITH (format='PARQUET')
AS
SELECT tenant_id, site_id, day,
       sum(os_count) AS os_count,
       avg(lead_time_days) AS lead_time_days
FROM gold.work_kpis_daily
GROUP BY 1,2,3;
```

### 6.2 *Materialized Views* — `performance/aggregates/materialized_views.sql`

```sql
CREATE MATERIALIZED VIEW gold_mv.os_kpi_month AS
SELECT tenant_id, date_trunc('month', day) AS month,
       sum(os_count) AS os_count_m,
       avg(lead_time_days) AS lead_time_m
FROM gold.work_kpis_daily
GROUP BY 1,2;
```

### 6.3 Caching — `performance/caching.md`

* **Query result cache** (Trino/Snowflake/BigQuery).
* **CDN** para *tiles* dos painéis.
* **Programar extratos** para BI (ex.: *extracts* do Power BI/Looker com TTL).

### 6.4 Guias de consulta — `performance/query-guides.md`

* **Particionamento** (`WHERE day BETWEEN ...`) e **pruning de colunas**.
* Evitar \*SELECT \* \*.
* Uso de **semântica**: priorizar métricas/ dimensões publicadas.

---

## 7) **Self-Service BI e Curadoria**

* **Cubo semântico** com métricas/dimensões aprovadas.
* **Pastas**: *Certified* (bloqueadas), *Exploratory* (time de dados revisa mensalmente).
* **Templates** de dashboard por persona (Executivo, Gestor de Obra, Analista, SRE/FinOps).

---

## 8) **Integrações com Manifestos 1–13**

* **Manif. 1/4 (SLO/Observabilidade)**: SLOs aparecem em *badges* nos dashboards; frescor/erro de dados gera alerta.
* **Manif. 6 (Infra)**: consultas parametrizadas por `tenant_id/site_id`; RLS via views.
* **Manif. 11 (FinOps)**: UoM (R\$/OS, R\$/apontamento) expostas e ligadas a orçamento mensal; alerta de anomalia.
* **Manif. 12 (AI/ML)**: camadas **gold/silver** alimentam **feature store**; KPIs de adoção de IA nos painéis.
* **Manif. 13 (Data Mesh)**: contratos garantem **compatibilidade** e **linhagem**; owners por domínio.

---

## 9) **Definition of Ready / Done (Analytics & BI)**

**Ready**

* *Gold* `work_kpis_daily`, `finops_daily_cost` e `sv_work_orders` publicados e testados.
* Catálogo de métricas inicial (os\_concluidas, lead\_time\_os, custo\_por\_os, taxa\_retrabalho).
* RLS configurada por `tenant_id`.

**Done**

* Camada semântica publicada (dbt-metrics + Looker/Lightdash).
* Dashboards **Executivo**, **Operacional** e **FinOps** em produção com **SLAs de frescor**.
* Alerta de **anomalia de unit economics** ativo.
* Processo de **versionamento de métricas** e **CI** de validação habilitados.

---

## 🔜 Próximos passos sugeridos

1. **Publicar** a camada semântica no Looker/Lightdash a partir dos YAMLs fornecidos.
2. **Configurar** o dashboard Executivo e validá-lo com *stakeholders* (Produto/Operações/Financeiro).
3. **Habilitar** alertas de frescor/anomalia e treinar os times a usar *filters* por tenant/site.
4. **Rodar** um ciclo de *metric review* com ADR para **R\$/OS** (escopo e exceções).

Deseja que eu siga para o **Manifesto 15 — *Segurança de Plataforma & LGPD Avançado (DPIA, DLP, Keys, Segredos, Data Residency)*** ou prefere ajustes neste pacote de **Analytics & BI** antes?
