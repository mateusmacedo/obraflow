# Manifesto 11 — **FinOps & Cost Governance**

*(Unit economics, showback/chargeback por tenant/obra, orçamentos, otimização contínua, automações e painéis)*

Este manifesto de FinOps foi **integrado com os padrões técnicos** definidos no plano de ação do monorepo, garantindo alinhamento entre arquitetura, desenvolvimento e operações. Estabelece a governança de custos do ObraFlow em ambiente cloud-native, abrangendo **modelo de alocação**, **taxonomia de custos**, **métricas (UoM)**, **painéis**, **alertas**, **orçamentos**, **análises (Athena/BigQuery)**, **OpenCost/Kubecost**, **práticas de otimização** e **integração com SLOs** e **GitOps**.

## 💰 Integração com Padrões de FinOps do Monorepo

### Stack de FinOps Integrada
- **Alocação**: OpenCost/Kubecost com labels padronizados
- **Analytics**: AWS CUR + Athena / GCP Billing + BigQuery
- **Dashboards**: Grafana com painéis por tenant e componente
- **Automação**: CI/CD gates de custo, ADRs de custo
- **Governança**: RBAC, taxonomia, orçamentos e alertas

### Padrões de FinOps Aplicados
- **TypeScript**: Scripts de análise de custo, dashboards Grafana
- **Go**: Ferramentas de otimização, análise de recursos
- **Cross-cutting**: Labels de custo, métricas de negócio, SLOs

---

## 📁 Estrutura de arquivos

```
finops/
  README.md
  governance/
    rbac.md
    taxonomy-labels.md
    chargeback-policy.md
    budgets-policy.md
    finops-rituals.md
  allocation/
    opencost-values.yaml
    kubecost-values.yaml         # (opcional se usar Kubecost)
    k8s-labels-conventions.yaml
    cost-mapping.yaml
  dashboards/
    grafana-finops-overview.json
    grafana-tenant-unit-economics.json
    looker-exec-finops.spec.md
  alerts/
    prometheus-anomaly-rules.yaml
    budgets-anomalies.yml
  analytics/
    aws-cur-athena/
      glue-ddl.sql
      sample-queries.sql
    gcp-bq-billing/
      dataset.sql
      queries.sql
  playbooks/
    rightsizing.md
    storage-lifecycle.md
    data-egress-optimization.md
    reserved-commitments.md
  automation/
    ci-cost-guard.yml
    argocd-image-costpolicy.yaml
    cost-adr-template.md
```

---

## 1) `finops/README.md` — Guia de uso

```markdown
# FinOps — ObraFlow

**Objetivo:** maximizar valor por R$ investido, mantendo SLOs (Manif. 1) e segurança (Manif. 3).

**Pilares:**
1. **Visibilidade** — OpenCost/Kubecost + CUR/BigQuery + tags/labels padronizados.
2. **Alocação** — showback/chargeback por tenant/obra, produto e componente.
3. **Otimização** — rightsizing, lifecycle, commitments, redes e dados gerenciados.
4. **Controle** — orçamentos, alertas de anomalia, *gates* de custo em CI/CD.
5. **Rituais** — *FinOps review* quinzenal, ADRs de custo para grandes mudanças.

**Unidade econômica (UoM):**
- **Custo por OS concluída (R$/OS)**,
- **Custo por apontamento (R$/apontamento)**,
- **Custo por obra ativa/mês (R$/obra·mês)**.
```

---

## 2) Governança

### 2.1 `governance/rbac.md`

* **Perfis**: *FinOps Admin* (define políticas), *Engineering Lead* (otimiza), *Product Owner* (prioriza trade-offs).
* **Princípio**: **Enablement > Policiamento**; decisões registradas em **ADR de custo**.

### 2.2 `governance/taxonomy-labels.md` — **Taxonomia & tagging obrigatórios** (K8s/IaC/Cloud)

```yaml
labels:
  obraflow.io/cost-center: { required: true, examples: ["work-mgmt","platform","observability"] }
  obraflow.io/component:   { required: true, examples: ["bff","sync","projection","ingest"] }
  obraflow.io/env:         { required: true, enum: ["dev","hml","prd"] }
  obraflow.io/tenant:      { required: true, examples: ["shared","acme","globex"] }
  obraflow.io/site:        { required: false, note: "Usar quando custo granular por obra for necessário" }
cloudTags:
  CostCenter:        mirror: obraflow.io/cost-center
  Environment:       mirror: obraflow.io/env
  Component:         mirror: obraflow.io/component
  Tenant:            mirror: obraflow.io/tenant
  Owner:             manual
enforcement:
  gatekeeper: require-labels # vide Manifesto 6 (gatekeeper-constraints.yaml)
  ci: block-pr-if-missing-labels
```

### 2.3 `governance/chargeback-policy.md`

* **Showback trimestral** → **chargeback mensal**.
* Alocação **direta** (K8s namespace/workload) e **indireta** (overhead, observabilidade, gateway) por **rate cards** (% ou driver de custo).
* **Driver**: CPU-h, GB-h, requests, armazenamento-GB-mês, egress-GB, mensagens Kafka-milhões.

### 2.4 `governance/budgets-policy.md`

* Orçamentos por **produto** e **tenant enterprise**, com **alertas 50/80/100%**.
* **Congelamento de release por custo** (ver `automation/ci-cost-guard.yml`) quando projeção mensal > orçamento em X%.

### 2.5 `governance/finops-rituals.md`

* **Quinzenal**: Rightsizing & Commitments.
* **Mensal**: Unit economics + anomalias.
* **Trimestral**: Rebalanceio de *rate cards* e planejar *commitments*.

---

## 3) Alocação (OpenCost/Kubecost + convenções)

### 3.1 `allocation/opencost-values.yaml` (OpenCost em K8s)

```yaml
opencost:
  exporter:
    prometheus:
      existingServiceName: prometheus # do stack de observabilidade (Manif. 4)
  aggregator:
    extraEnv:
      - name: CLUSTER_ID
        value: "obraflow-prod"
  metrics:
    clusterInfo: true
  ui:
    enabled: true
allocation:
  emitKsmV1Metrics: true
  emitKsmV2Metrics: true
  labelConfig:
    enabled: true
    labelMappings:
      - containerLabel: "obraflow.io/cost-center"
        label: "cost_center"
      - containerLabel: "obraflow.io/tenant"
        label: "tenant"
      - containerLabel: "obraflow.io/component"
        label: "component"
```

> Se preferir **Kubecost**, fornecemos `allocation/kubecost-values.yaml` equivalente, com integração CUR.

### 3.2 `allocation/k8s-labels-conventions.yaml`

* Reflete as **labels** já implantadas nos charts do Manifesto 6.
* **Gatekeeper** impede deploy sem `obraflow.io/cost-center` e `obraflow.io/component`.

### 3.3 `allocation/cost-mapping.yaml`

```yaml
overhead:
  observability: 0.08   # 8% do custo de cluster proporcional a CPU-h consumido por time
  mesh_gateway:  0.03
  shared_services: 0.05
rateCards:
  kafka_per_million_msgs: 2.40   # R$ por milhão de msgs
  storage_gb_month: 0.35         # R$/GB·mês (S3 classe padrão)
  egress_gb: 0.45
drivers:
  work_mgmt:
    cpu_weight: 0.6
    mem_weight: 0.4
```

---

## 4) Dashboards (Grafana)

### 4.1 `dashboards/grafana-finops-overview.json` (resumo executivo)

Inclui:

* Custo diário por **produto** e **env** (stacked).
* Custo por **tenant** (top N).
* **R\$/OS concluída** e **R\$/apontamento** (via join com métricas de negócio).
* Projeção MTD vs orçamento.

*(excerto JSON)*:

```json
{
  "title": "FinOps — Overview",
  "panels": [
    { "type": "bargauge", "title": "Custo diário (R$) por produto", "targets": [
      { "expr": "sum by (cost_center)(rate(opencost_cost_total{env=\"prd\"}[1d]))" }
    ]},
    { "type": "timeseries", "title": "R$/OS (UoM)",
      "targets": [
        { "expr": "sum(rate(opencost_cost_total{cost_center=\"work-mgmt\",env=\"prd\"}[1d])) / sum(increase(biz_work_orders_completed_total{env=\"prd\"}[1d]))" }
      ]
    }
  ],
  "schemaVersion": 38
}
```

### 4.2 `dashboards/grafana-tenant-unit-economics.json`

* Custo por **tenant/site** com drill-down: compute, storage, rede, dados gerenciados.
* KPI **custo por obra·mês** (baseado em `tenant, site`).

---

## 5) Alertas e Orçamentos

### 5.1 `alerts/prometheus-anomaly-rules.yaml` (anomaly/baseline)

```yaml
groups:
  - name: finops-anomaly
    interval: 5m
    rules:
      - alert: CostAnomalyDaily
        expr: |
          (sum(rate(opencost_cost_total{env="prd"}[1d])) by (cost_center))
          >
          (1.4 * sum(avg_over_time(opencost_cost_total{env="prd"}[7d])) by (cost_center))
        for: 30m
        labels: { severity: ticket }
        annotations:
          summary: "Anomalia de custo (>40% acima da média 7d) em {{ $labels.cost_center }}"
          description: "Verificar deploys recentes, HPA e tráfego."
```

### 5.2 `alerts/budgets-anomalies.yml` (controle por orçamento; executado por job/Action)

```yaml
budgets:
  - name: work-mgmt-prd
    monthly_cap_r$: 12000
    thresholds: [0.5, 0.8, 1.0]
    notify: ["#finops", "email:finops@obraflow.example"]
  - name: observability-prd
    monthly_cap_r$: 3000
    thresholds: [0.7, 0.9, 1.0]
```

---

## 6) Analytics (CUR / BigQuery Billing)

### 6.1 `analytics/aws-cur-athena/glue-ddl.sql`

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS cur_obraflow (
  identity Line,
  bill Line,
  line_item Line,
  resource_tags Map<string,string>
)
PARTITIONED BY (bill_payer_account_id string, year string, month string)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
STORED AS PARQUET
LOCATION 's3://<CUR-BUCKET>/cur/obraflow/';
```

### 6.2 `analytics/aws-cur-athena/sample-queries.sql`

```sql
-- Custo por label 'obraflow.io/cost-center'
SELECT resource_tags['obraflow.io/cost-center'] AS cost_center,
       SUM(COALESCE(line_item_unblended_cost, 0)) AS cost_r$
FROM cur_obraflow
WHERE year='2025' AND month='09'
GROUP BY 1
ORDER BY 2 DESC;

-- Egress (GB) por serviço
SELECT product_product_name, SUM(line_item_usage_amount) AS gb
FROM cur_obraflow
WHERE line_item_usage_type LIKE '%DataTransfer-Out-Bytes%'
  AND year='2025' AND month='09'
GROUP BY 1 ORDER BY 2 DESC;
```

### 6.3 `analytics/gcp-bq-billing/queries.sql` (equivalente BigQuery)

```sql
-- Custo por tenant
SELECT labels.value AS tenant,
       SUM(cost) AS cost_r$
FROM `billing.gcp_export_v1_*`,
UNNEST(labels) labels
WHERE labels.key='obraflow.io/tenant'
GROUP BY tenant
ORDER BY cost_r$ DESC;
```

---

## 7) Playbooks de Otimização

### 7.1 `playbooks/rightsizing.md`

* **Sinais**: CPU < 30% e memória < 50% p95 por 7d → *target* de redução.
* **Ação**: ajustar `requests/limits` e **HPA** (Manifesto 6) + validar SLOs (Manifesto 1).
* **Ferramentas**: *Vertical Pod Autoscaler* em modo *recommendation*, *Karpenter consolidation*.
* **Banco gerenciado**: dimensionar por *max connections* e IOPS reais.

### 7.2 `playbooks/storage-lifecycle.md`

* S3: **classes** (Standard → IA → Glacier) com **lifecycle policy** por *tag* `sensitivity=low`.
* **TTL** alinhada à LGPD (Manif. 3) e à **DPIA** (mídia 365d).
* Postgres: *partitioning* por data para facilitar *vacuum* e **retention**.

### 7.3 `playbooks/data-egress-optimization.md`

* **CDN** e **cache** para downloads de mídia.
* **Compression** (gzip/zstd) onde aplicável.
* **Colocalização** de serviços com dados.
* Evitar *chatty APIs* (usar delta/ETag; ver Manifesto 5).

### 7.4 `playbooks/reserved-commitments.md`

* **Savings Plans/Committed Use** com cobertura alvo 70–80% da *base load*.
* **Spot** para workloads tolerantes (jobs, analytics).
* Revisar **anualmente** por mudanças de perfil.

---

## 8) Automação

### 8.1 `automation/ci-cost-guard.yml` — *Gate* de custo por PR

```yaml
name: Cost Guard
on:
  pull_request:
    paths:
      - "infra/**"
      - "charts/**"
      - "workloads/**"
jobs:
  estimate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: OpenCost diff (simulado)
        run: |
          # Exemplo: consultar API do OpenCost ou Kubecost com payload hipotético
          echo "estimated_r_per_month=+1200" >> $GITHUB_OUTPUT
      - name: Block if exceeds threshold
        run: |
          THRESHOLD=1000
          if (( ${estimated_r_per_month#+} > THRESHOLD )); then
            echo "::error::Projeção de +R$${estimated_r_per_month}/mês > R$${THRESHOLD}. Adicione ADR de custo e aprovação FinOps."
            exit 1
          fi
```

### 8.2 `automation/argocd-image-costpolicy.yaml` — *Policy* de imagens

* Bloquear imagens sem *multi-arch* quando houver *nodepool spot ARM* mais barato.
* Exigir *compressão* (zstd/gzip) em *artifacts*.

### 8.3 `automation/cost-adr-template.md`

```markdown
# ADR de Custo — <Título>
Contexto: <serviço, motivação>
Decisão: <infra, instâncias, classe de storage, tier de DB>
Impacto (R$/mês): <estimativa> | UoM afetado: <R$/OS, R$/apontamento>
Alternativas consideradas: <A/B/C>
Métricas de sucesso: <redução %, payback em meses>
```

---

## 9) Integrações com Manifestos anteriores

* **Manif. 1 (SLO)**: *freeze* por SLO já integrado; custo **não** pode violar SLO (trade-off consciente).
* **Manif. 3 (LGPD)**: **lifecycle** e **retenção** também são controles de custo (e compliance).
* **Manif. 4 (Observabilidade)**: OpenCost usa Prometheus; painéis e exemplars mapeiam **custo ↔ rotas**.
* **Manif. 5 (API)**: ETag/condicional e delta reduzem tráfego e **egress**.
* **Manif. 6 (Infra)**: HPA/PDB/Karpenter; *Spot* e *limits* coerentes.
* **Manif. 7 (Tests)**: *Synthetics* + asserts de latência protegem contra **over-provisioning** por “cargo-cult”.
* **Manif. 8 (Release)**: *gates* de custo em CI e “canary costeiro” (observa custo por requisição).
* **Manif. 9 (Incidentes)**: **anomalias de custo** ativam *paging* quando extremos (ex.: loop de retry).
* **Manif. 10 (DR/BCP)**: *class storage* e *snapshots* com política de retenção **cost-aware**.

---

## 10) Definition of Ready / Done (FinOps)

**Ready**

* Labels/tags padronizados e **Gatekeeper** ativo.
* OpenCost/Kubecost implantado e **validado**.
* Data pipelines CUR/BigQuery ativos.

**Done**

* Painéis (overview + tenant) publicados.
* Alertas de **anomalia** e **orçamento** ativos.
* Rightsizing aplicado a ≥ 30% dos serviços elegíveis.
* **UoM (R\$/OS, R\$/apontamento)** monitorados por 2 ciclos.
* ADRs de custo para mudanças > R\$ 1.000/mês.

---

### Próximos passos sugeridos

1. **Ativar OpenCost/Kubecost** com `opencost-values.yaml` e validar labels (Manifesto 6).
2. Publicar os **dashboards** e configurar **alerts** (anomalia e orçamento).
3. Rodar o primeiro **Rightsizing Day** (playbook) e registrar **ADRs**.
4. Integrar **UoM** ao *roadmap* de produto (metas de R\$/OS).

## 🔄 Integração com Padrões do Monorepo

### Estrutura de FinOps Aplicada
```
obraflow/
├── finops/
│   ├── governance/                  # Políticas e RBAC
│   ├── allocation/                  # OpenCost/Kubecost configs
│   ├── dashboards/                  # Grafana dashboards
│   ├── alerts/                      # Prometheus rules
│   ├── analytics/                   # CUR/BigQuery queries
│   └── playbooks/                   # Playbooks de otimização
├── .github/workflows/
│   └── ci-cost-guard.yml           # Gates de custo
└── tools/scripts/finops/           # Scripts de análise
```

### Padrões de FinOps por Linguagem
- **TypeScript**: Dashboards Grafana, scripts de análise, ADRs de custo
- **Go**: Ferramentas de otimização, análise de recursos, métricas
- **Cross-cutting**: Labels de custo, métricas de negócio, SLOs

### Critérios de Aceite de FinOps
- **Labels de custo** aplicados em todos os recursos
- **Dashboards** funcionando com métricas de negócio
- **Gates de custo** ativos no CI/CD
- **ADRs de custo** para mudanças significativas

Deseja que eu avance para o **Manifesto 12 — *AI/ML Ops para Assistentes & Otimização de Recursos (IA aplicada ao ObraFlow)***, cobrindo recomendações de alocação, previsões de consumo e copilots de obra (incl. custos de inferência/treino), ou prefere ajustar algo neste FinOps antes?
