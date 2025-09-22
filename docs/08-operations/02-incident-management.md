# Manifesto 9 — **Runbooks & Incident Management**

*(RACI, Severidades, Paging, Fluxo de Incidente, Comms, RCA Blameless, Ações Corretivas, Exemplos de Runbooks)*

Abaixo está o **pacote inicial** para operacionalizar resposta a incidentes do ObraFlow. Inclui **política**, **processos**, **templates**, **checklists**, **KPIs (MTTA/MTTR)** e **runbooks prontos** para falhas típicas (sync mobile, Kafka lag, DB saturado, regressão de release). Coeso com os Manifestos 1–8.

---

## 📁 Estrutura de arquivos

```
operations/
  README.md
  incident-management/
    policy.md
    roles-raci.md
    severity-matrix.md
    lifecycle.md
    paging-playbook.md
    communications/
      status-template.md
      customer-email-template.md
      internal-briefing-template.md
      incident-channel-checklist.md
    kpis-metrics.md
    rca/
      postmortem-template.md
      action-tracking.md
      taxonomy.md
  runbooks/
    index.md
    mobile-sync-backlog.md
    kafka-lag.md
    db-connection-saturation.md
    release-regression-rollback.md
    api-error-spike.md
    storage-s3-minio-issues.md
    observability-outage.md
  tools/
    shortcuts.md
    queries/
      prometheus.md
      loki.md
      tempo.md
      postgres.sql
      kafka.md
    scripts/
      argo-rollback.sh
      canary-freeze.sh
      dlq-drain.sh
```

---

## 1) `operations/README.md`

```markdown
# Operações — Incidentes & Runbooks

Este diretório contém **políticas**, **processos**, **templates** de comunicação e **runbooks** para incidentes.
Objetivos: reduzir **MTTA/MTTR**, padronizar resposta, alinhar *blameless culture* e garantir **lições aprendidas**.

Leitura essencial:
1. `incident-management/policy.md` (como declaramos e tocamos incidentes).
2. `incident-management/severity-matrix.md` (quando é Sev1..Sev4).
3. `incident-management/paging-playbook.md` (como acionar plantão).
4. `runbooks/index.md` (lista dos principais runbooks).
```

---

## 2) Política e Processo

### `incident-management/policy.md`

```markdown
# Política de Gerenciamento de Incidentes

- **Definição:** Evento não planejado que degrada SLOs, segurança, custo ou conformidade.
- **Princípios:** Segurança primeiro, comunicação frequente, *blameless*, dados > opiniões, foco no cliente.
- **SLAs de Resposta (MTTA/MTTR meta):**
  - Sev1: MTTA ≤ 5 min, MTTR ≤ 60 min
  - Sev2: MTTA ≤ 15 min, MTTR ≤ 4 h
  - Sev3: MTTA ≤ 1 h, MTTR ≤ 24 h
  - Sev4: Melhor esforço (sem impacto a clientes)

- **Critérios de abertura:** Qualquer violação de SLO, alerta *page*, vazamento potencial de dados, custos em burn anormal (FinOps), incidente de segurança.

- **Ferramentas oficiais:** PagerDuty/Opsgenie, Slack/Teams, Status Page, ArgoCD, Grafana, Prometheus, Loki, Tempo, k9s/kubectl, Kafka CLI.
```

### `incident-management/roles-raci.md`

```markdown
# RACI e Papéis (por incidente)

- **Incident Commander (IC)** — *Accountable*: coordena, decide, mantém foco.
- **Comms Lead (CL)** — *Responsible*: escreve atualizações internas/externas.
- **Ops Lead (Ops)** — *Responsible*: executa diagnóstico/mitigação.
- **Subject Matter Expert (SME)** — *Consulted*: especialista da área (ex.: Kafka, DB, mobile).
- **Scribe** — *Responsible*: registra linha do tempo, decisões e métricas.
- **Stakeholders (PO/CS/Sec)** — *Informed*.

> **Regra:** uma pessoa = um chapéu por vez. O IC não digita comandos.
```

### `incident-management/severity-matrix.md`

```markdown
# Severidades

| Sev | Impacto | Exemplo | Comunicação | Janela RCA |
|-----|---------|---------|-------------|------------|
| 1   | P0: indisponibilidade total, vazamento confirmado, perda de dados | API 5xx>20% contínuo | Atualização a cada 15 min, Status Page público | 48h |
| 2   | P1: degradação severa (SLO violado), risco alto | p95>1s por 30 min, DLQ > 1% | A cada 30 min, Status Page se afetar clientes | 3 dias úteis |
| 3   | P2: funcionalidade parcial afetada | Sync atrasado > 2h | A cada 2 h (interno) | 5 dias úteis |
| 4   | P3: baixo impacto / workaround | Bug UX sem impacto em SLO | Ao encerrar | Opcional |
```

### `incident-management/lifecycle.md`

```markdown
# Ciclo de Incidente

1) **Detect**: alerta (Prometheus/Loki/Tempo), cliente, time.
2) **Declare**: IC nomeado, canal #inc-YYYYMMDD-N, Sev definida.
3) **Stabilize**: mitigar (feature flag, canary freeze, rollback), preservar evidências.
4) **Diagnose**: hipóteses, gráficos, logs, traces; evitar *thrash*.
5) **Communicate**: ritmo (conforme Sev), registro de updates.
6) **Resolve**: SLO normalizado, verificar ausência de regressões.
7) **RCA**: postmortem blameless, ações corretivas com *owners* e prazos.
8) **Learn**: revisar runbook/painel/alerta, criar ADR se necessário.
```

### `incident-management/paging-playbook.md`

```markdown
# Paging

- Alerta `severity: page` dispara para *Primary On-Call* (24/7).
- Sem ACK em 5 min → escalonamento automático para *Secondary*.
- IC é o *on-call* até delegar. Registrar no canal: IC, CL, Scribe.
- *Hand-off* formatado (contexto, status, próximos passos).
```

---

## 3) Comunicação

### `communications/status-template.md`

```markdown
# [STATUS] Incidente {SevN} — {Resumo curto}
**Início:** 2025-09-21T12:10Z | **Referência:** INC-2025-09-21-01

**Impacto:** (quem, onde, o quê)
**Sintomas:** (ex.: erro 5xx ~18%, p95 1.2s)
**Mitigação atual:** (ex.: flag OFF em `work.alloc.ai_suggestions`, canário 0%)
**Próximos passos:** (ex.: drenar DLQ, subir réplicas)
**Próxima atualização:** (ex.: 15 min)
```

### `communications/customer-email-template.md`

```markdown
Assunto: Atualização sobre indisponibilidade parcial do ObraFlow (INC-XXXX)

Prezados,

Entre HH:MM e HH:MM BRT, parte dos usuários enfrentou [sintoma].
A equipe mitigou realizando [ação] e o serviço encontra-se estável.

Próximos passos:
- [Ação corretiva] com prazo [data].
- RCA blameless será publicado até [data].

Pedimos desculpas pelo transtorno.
Atenciosamente,
Equipe ObraFlow
```

### `communications/internal-briefing-template.md`

```markdown
# Briefing Interno — INC-XXXX
- **Causa provável** (atual): …
- **Linhas de investigação**: …
- **Riscos**: …
- **Ajuda necessária**: …
```

### `communications/incident-channel-checklist.md`

```markdown
- [ ] Título do canal #inc-YYYYMMDD-N setado com Sev
- [ ] IC, CL, Scribe definidos
- [ ] Linha do tempo iniciada (pinned)
- [ ] Status Page configurado (se aplicável)
- [ ] Plano de mitigação & próxima atualização definidos
```

---

## 4) KPIs e Métricas

### `incident-management/kpis-metrics.md`

```markdown
# KPIs

- **MTTA** (acknowledge): alvo por Sev (5/15/60 min).
- **MTTR**: conforme matriz.
- **Frequência por causa-raiz** (taxonomy).
- **Mudanças causadoras** (% incidentes por release).
- **Cobertura de runbooks** (# incidentes sem runbook).
- **Aderência a RCA** (% ações corretivas concluídas no prazo).
```

---

## 5) RCA Blameless

### `incident-management/rca/postmortem-template.md`

```markdown
# Postmortem — INC-YYYYMMDD-N (SevN)
**Resumo executivo:** 1–2 parágrafos.

## Linha do tempo (UTC)
- 12:10: Alerta p95>300ms (Prometheus)
- 12:12: IC declarado; Sev2
- …

## Impacto
- SLO afetados, clientes, duração.

## Detecção
- Como detectamos (alerta/cliente) e **tempo de detecção**.

## Causa-raiz
- 5 Whys / Diagrama de Ishikawa (anexar).

## O que funcionou / O que faltou
- (alarmas, dashboards, runbooks, playbooks)

## Ações corretivas (SMART)
| ID | Ação | Owner | Prazo | Status |
|----|------|-------|-------|--------|
| AC-01 | Ajustar retry/timeout no BFF | @alice | YYYY-MM-DD | Em curso |

## Anexos
- Gráficos, logs, traces, PRs, ADRs.
```

### `incident-management/rca/action-tracking.md`

```markdown
- Todas as ações corretivas recebem **ID**, **owner**, **prazo** e **severity**.
- Itens AC bloqueiam promoções caso marcados como *must-fix* (ver Release Policy).
- Revisão semanal em *operational review*.
```

### `incident-management/rca/taxonomy.md`

```markdown
# Taxonomia (causas-raiz)

- **Mudança** (config, código, infra), **Capacidade**, **Dependência externa**, **Dados**, **Segurança**, **Processo**.
```

---

## 6) Runbooks (amostras completas)

### `runbooks/index.md`

```markdown
# Runbooks — Índice

- Mobile Sync backlog — `mobile-sync-backlog.md`
- Kafka lag — `kafka-lag.md`
- DB connection saturation — `db-connection-saturation.md`
- Release regression / rollback — `release-regression-rollback.md`
- API error spike (5xx) — `api-error-spike.md`
- Storage (S3/MinIO) issues — `storage-s3-minio-issues.md`
- Observability outage — `observability-outage.md`
```

#### 6.1 `mobile-sync-backlog.md`

```markdown
# Mobile Sync Backlog

**Sintoma:** `mobile:sync:staleness > 60s` (alerta) ou reclamações de dados desatualizados.

## Diagnóstico rápido (10 min)
1) Painel "ObraFlow — Sync Mobile": verificar `staleness`, taxa de falha de sync, p95 `/sync/delta`.
2) Conferir filas/outbox: `kafka lag` nos tópicos de projeção.
3) Logs BFF `/sync/delta` (Loki): `status: 5xx OR 429`.

## Ações de mitigação
- Aumentar réplicas do serviço `sync-mobile` (HPA override temporário).
- Ativar **modo compacto** de delta (feature flag `sync.delta.compact=true`).
- Se DLQ presente > 0.1%: rodar `scripts/dlq-drain.sh` (com idempotência).

## Verificações
- p95 do endpoint < 300ms por 15 min.
- `staleness` volta < 60s.

## Follow-up
- Revisar tamanho dos *batches*, compressão, ETag/If-Modified-Since.
```

#### 6.2 `kafka-lag.md`

```markdown
# Kafka Lag

**Sintoma:** `KafkaLagGrowing` (alerta) ou consumos atrasados.

## Diagnóstico
- `kafka-consumer-groups --bootstrap-server ... --describe --group obraflow-work-projections`
- Painel "Kafka Health": lag por group, taxa de processamento, DLQ.

## Mitigação
- Escalar consumidores (réplicas).
- Habilitar *readiness* agressivo (evitar *thrash*).
- Se **poison pill**: enviar para DLQ e investigar schema (ver Manifesto 2).

## Pós-ação
- Confirmar projeções atualizadas; criar ação corretiva se schema mudou sem compat.
```

#### 6.3 `db-connection-saturation.md`

```markdown
# DB Connection Saturation

**Sintoma:** erros `too many connections` ou queda de throughput.

## Diagnóstico
- `kubectl exec -it ... -- psql -c "select * from pg_stat_activity;"` (Postgres)
- Métricas: pool in use, filas no BFF, latência p95.

## Mitigação
- Aumentar pool gradualmente; aplicar *circuit breaker* (leitura via projeções).
- Habilitar cache/ETag no BFF para endpoints quentes.
- Limitar *burst* via rate-limit por tenant.

## Follow-up
- Index/tuning, *connection pooling* compartilhado, revisar N+1 queries.
```

#### 6.4 `release-regression-rollback.md`

```markdown
# Release Regression / Rollback

**Gatilho:** ErrorRateHigh / LatencyP95Breaching pós-deploy.

## Procedimento
1) **Congelar tráfego**: `scripts/canary-freeze.sh` (canário → 0%).
2) **Rollback**: `scripts/argo-rollback.sh <app> <rev>` (reverter a última revisão).
3) **Verificar**: p95/5xx normalizam? DLQ sem crescimento?

## Comunicação
- Atualização em 15 min; rationale do rollback; plano para fix forward.
```

#### 6.5 `api-error-spike.md`

```markdown
# API Error Spike

**Sintoma:** 5xx > 1% por 10 min.

## Diagnóstico
- Top rotas com erro (Grafana → RED Overview).
- Correlacionar com traces (exemplars).
- Checar *feature flags* novas.

## Mitigação
- Desativar flags relacionadas.
- Ajustar *timeouts* e *retries* no VirtualService (Istio).
- Se regressão clara, seguir `release-regression-rollback.md`.
```

*(demais runbooks nos arquivos listados)*

---

## 7) Ferramentas, Comandos & Scripts

### `tools/shortcuts.md` (atalhos)

```markdown
- kubectl: `k top po -n obraflow-app`, `k logs -n obraflow-app deploy/work-mgmt -f`
- k9s: navegação rápida por namespace e logs
- ArgoCD: `argocd app history <app>`, `argocd app rollback <app> <id>`
- Kafka: `kafka-consumer-groups --describe --group <grp>`
```

### `tools/queries/prometheus.md`

```markdown
# Queries úteis (Prometheus)

- p95 por rota:
histogram_quantile(0.95, sum by (le, route)(rate(http_server_duration_seconds_bucket{env="prd"}[5m])))
- erro 5xx %:
sum(rate(http_requests_total{env="prd",status=~"5.."}[5m])) / sum(rate(http_requests_total{env="prd"}[5m]))
- staleness sync:
max by(tenant,site) (timestamp() - last_successful_sync_timestamp_seconds)
```

### `tools/queries/loki.md`

```markdown
{namespace="obraflow-app"} |= "ERROR" | json | line_format "{{.msg}} tenant={{.tenant_id}} corr={{.correlation_id}}"
```

### `tools/queries/postgres.sql`

```sql
-- Sessões por usuário
select usename, count(*) from pg_stat_activity group by 1 order by 2 desc;

-- Locks atuais
select pid, locktype, relation::regclass, mode, granted from pg_locks l left join pg_stat_activity a using (pid);
```

### `tools/scripts/argo-rollback.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
APP="${1:?app name}"; REV="${2:-1}"
argocd app history "$APP"
argocd app rollback "$APP" "$REV"
```

### `tools/scripts/canary-freeze.sh`

```bash
#!/usr/bin/env bash
# Zera peso do subset canário (se usar Argo Rollouts/Istio)
kubectl patch vs work-mgmt -n obraflow-app --type=json \
  -p='[{"op":"replace","path":"/spec/http/0/route/0/weight","value":100},{"op":"replace","path":"/spec/http/0/route/1/weight","value":0}]'
```

### `tools/scripts/dlq-drain.sh`

```bash
#!/usr/bin/env bash
# Drena mensagens da DLQ para arquivo (para reprocessamento controlado)
TOPIC="${1:?topic.dlq}"
kafka-console-consumer --bootstrap-server $BS --topic "$TOPIC" --from-beginning --timeout-ms 60000 > dlq_dump.ndjson
```

---

## 8) Amarrações com Manifestos 1–8

* **SLOs & Alertas** (Manif. 1 & 4): gatilhos de incidente, queries e dashboards referenciados.
* **Eventos & DLQ** (Manif. 2): runbook para lag/poison pill.
* **Segurança & LGPD** (Manif. 3): inclui fluxo para incidentes de segurança (comms, notificação a titulares/autoridades conforme DPIA).
* **API Governance** (Manif. 5): erros padronizados (RFC 7807) facilitam diagnóstico.
* **Infra/GitOps** (Manif. 6): rollback via Argo, políticas de rede/mesh.
* **Test Strategy** (Manif. 7): ações corretivas geram testes de regressão; drills periódicos.
* **Release/Change** (Manif. 8): *freeze* por SLO, CAB leve, post-release verification.

---

Posso avançar com o **Manifesto 10 — *DR/BCP (RTO/RPO, Backups, Restaurabilidade, Regiões, Exercícios)***, ou deseja ajustar algo no pacote de **Runbooks & Incident Management** antes?
