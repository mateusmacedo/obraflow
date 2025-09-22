# Manifesto 10 — **DR/BCP (Disaster Recovery & Business Continuity Plan)**

*(RTO/RPO, Topologias Multi-AZ/Região, Backups & PITR, Exercícios, Runbooks, Métricas e IaC de referência)*

Este pacote estabelece a **estratégia operacional de continuidade de negócio** e **recuperação de desastres** do ObraFlow. Abrange níveis de criticidade, metas **RTO/RPO**, arquitetura de resiliência (AZ/Região), **procedimentos de recuperação** por tecnologia (Postgres, Mongo, Kafka, S3/MinIO, Redis, OpenSearch), **exercícios e auditoria**, **ransomware & chave KMS comprometida**, comunicação e governança. Coeso com Manifestos 1–9 (SLO, Segurança/LGPD, Observabilidade, GitOps, Testes, Releases e Incidentes).

---

## 📁 Estrutura de arquivos

```
dr-bcp/
  README.md
  policy.md
  criticality-matrix.md
  rto-rpo-table.md
  topologies.md
  data-protection/
    postgres-pitr.md
    mongo-pitr.md
    kafka-mm2.md
    s3-crr.md
    redis-backup.md
    opensearch-snapshots.md
  procedures/
    regional-failover.md
    az-failover.md
    partial-restore.md
    ransomware-response.md
    kms-compromise.md
  exercises/
    program.md
    scenarios.md
    evidence-template.md
  monitoring/
    kpis.md
    grafana-panels.json
    alerting-rules.yaml
  bcp/
    process-map.md
    manual-workarounds.md
    vendor-contacts.md
    communication-plan.md
  iac/
    velero-values.yaml
    wal-g-statefulset.yaml
    kafka-mm2-deployment.yaml
    route53-failover.yaml
    opensearch-snapshot-policy.json
```

---

## 1) `README.md` — Guia de navegação

```markdown
# DR/BCP — ObraFlow

Objetivo: manter continuidade de negócio (BCP) e recuperar a plataforma (DR) dentro de **RTO/RPO** acordados.

Como usar:
1) Classifique cargas (`criticality-matrix.md`) e defina **RTO/RPO** (`rto-rpo-table.md`).
2) Selecione topologia por sistema (`topologies.md`).
3) Implemente proteção de dados por tecnologia (pasta `data-protection/`).
4) Siga procedimentos de failover/restore (pasta `procedures/`).
5) Execute e evidencie exercícios (pasta `exercises/`).
6) Monitore KPIs e alertas (`monitoring/`).
7) BCP: mapeamento de processos, *workarounds*, fornecedores e comunicação (pasta `bcp/`).
```

---

## 2) `criticality-matrix.md` — Matriz de criticidade (serviço × negócio)

```markdown
# Criticidade (C0–C3)

- **C0 (Missão crítica)**: Sync Mobile, BFF/API pública, Work Management (OS), Medição (faturamento).
- **C1 (Alta)**: Alocação/Recursos, Suprimentos, Autenticação (IdP), Telemetria base.
- **C2 (Média)**: Analytics, Relatórios, Processos batch não financeiros.
- **C3 (Baixa)**: Labs/experimentos, ambientes dev.

Decisões de DR priorizam **C0/C1**.
```

---

## 3) `rto-rpo-table.md` — Metas por domínio

```markdown
# RTO/RPO (alvos)

| Domínio/Sistema           | RTO       | RPO        | Notas                                            |
|---------------------------|-----------|------------|--------------------------------------------------|
| BFF/API (prod)            | ≤ 60 min  | ≤ 5 min    | Multi-AZ + failover regional DNS                 |
| Sync Mobile               | ≤ 60 min  | ≤ 15 min   | Cache local do app atenua indisponibilidade      |
| Work Mgmt (Postgres)      | ≤ 60 min  | ≤ 5 min    | WAL-G + PITR + réplica cross-region              |
| Eventing (Kafka)          | ≤ 60 min  | ≤ 5 min    | MM2 (replicação) + reprocessamento idempotente   |
| Mídia (S3/MinIO)          | ≤ 4 h     | ≤ 1 h      | CRR (replicação inter-região) + versões          |
| Mongo (Docs/Checklists)   | ≤ 2 h     | ≤ 15 min   | Oplog/PITR + réplicas                            |
| OpenSearch (logs/analytics)| ≤ 4 h    | ≤ 1 h      | Snapshots periódicos                             |
| Redis (cache/locks)       | ≤ 30 min  | ≤ 0 min    | Recriável; persistência AOF opcional             |
```

---

## 4) `topologies.md` — Topologias de alta disponibilidade

```markdown
# Topologias

## Multi-AZ (padrão)
- K8s gerenciado + nós em ≥ 3 AZs.
- Postgres HA (líder + réplicas AZ), Redis replicado, Kafka brokers espalhados.

## Failover Regional Ativo-Passivo
- Região primária: tráfego 100%.
- Região secundária: quente (infra pronta, dados replicando).
- DNS failover (Route53/Cloud DNS) com health checks do Gateway.
- Promover serviços **C0/C1** em ≤ 60 min.

## Ativo-Ativo (selecionado)
- Apenas para BFF/API e Assets estáticos (CDN), mantendo **source of truth** único por banco (evitar multi-write).
```

---

## 5) Proteção de dados por tecnologia (`data-protection/*`)

### 5.1 `postgres-pitr.md` — Postgres (PITR com WAL-G)

* **Backups completos**: diário 03:00 BRT.
* **WAL (Write-Ahead Logs)**: contínuo → storage imutável com versionamento.
* **PITR**: restaurar para *timestamp* com `WAL-G`.
* **Criptografia**: do lado do servidor (KMS) + transporte TLS.
* **Teste**: exercício mensal de restauração em ambiente isolado (tempo alvo ≤ 30 min).

`iac/wal-g-statefulset.yaml` (trecho)

```yaml
env:
  - name: WALG_S3_PREFIX
    value: s3://obraflow-pg-backups/prod
  - name: AWS_KMS_KEY_ID
    valueFrom: { secretKeyRef: { name: pg-kms, key: key_id } }
  - name: WALG_DISK_RATE_LIMIT
    value: "104857600"
```

### 5.2 `mongo-pitr.md` — MongoDB

* **Replica set** com **journal** + **oplog**.
* **Backups**: snapshots + **PITR** com replay de oplog.
* **Restore parcial**: coleção por *point in time* para corrigir deleções.

### 5.3 `kafka-mm2.md` — Kafka (MirrorMaker 2)

* **Replicação inter-região** de tópicos **C0/C1** (eventos de OS, alocação, medição).
* **Política**: replicar `*.v1` e `.dlq`.
* **Reprocessamento**: consumidores suportam **idempotência** (chave `idempotencyKey`).
* **Cutover**: alterar *bootstrap* e reconfigurar *consumer groups*.

`iac/kafka-mm2-deployment.yaml` (trecho)

```yaml
spec:
  containers:
    - name: mm2
      image: confluentinc/cp-kafka-connect:7.6.0
      env:
        - name: CONNECT_CONFIG_PROVIDERS
          value: "file"
      volumeMounts:
        - name: mm2-config
          mountPath: /etc/kafka-connect/mm2.properties
```

### 5.4 `s3-crr.md` — S3/MinIO (Cross-Region Replication)

* Versionamento **ligado**; CRR para bucket secundário.
* **Bloqueio de objetos** (WORM) opcional para evidências.
* **Expurgo** conforme LGPD (retention & lifecycle).

`iac/route53-failover.yaml` (DNS de failover — excerto)

```yaml
# Health check + registros primário/secundário com peso/Failover
```

### 5.5 `redis-backup.md`

* **AOF** (append-only) com `everysec` quando usar como *source of truth* (raro).
* Senão, tratar como **cache** (RPO 0, reconstruível).
* **Snapshots**: a cada 6h, retenção 7 dias.

### 5.6 `opensearch-snapshots.md`

* **Snapshot repos** diários + retenção 7/30 dias (curto/longo prazo).
* Útil para **forense** em incidentes.

`iac/opensearch-snapshot-policy.json` (exemplo ILM/ISM).

---

## 6) Procedimentos de recuperação (`procedures/*`)

### 6.1 `regional-failover.md` — Failover de Região (ativo-passivo)

**Pré-requisitos**

* Infra secundária provisionada por GitOps (ArgoCD *synced*).
* Réplicas ativas (Postgres streaming, MM2, CRR).
* Alarmes verdes (lag, atraso de WAL, status do MirrorMaker).

**Passo a passo (tempo alvo ≤ 60 min)**

1. **Declarar incidente** (Sev1) e nomear IC (ver Manif. 9).
2. **Congelar** deploys na primária (Release Freeze).
3. **Postgres**: promover réplica (`pg_ctl promote`/RDS Multi-AZ promote).
4. **Kafka**: repontar produtores/consumidores para cluster secundário (variáveis/env + secret rotation).
5. **Storage**: confirmar CRR atualizado; atualizar *signed URLs* apontando para bucket secundário.
6. **Gateway/DNS**: alterar Route53 *failover record* para secundária (health check).
7. **Verificações**: health de BFF/API, Sync, backlog de filas, p95 < 300ms.
8. **Comunicação**: Status Page + e-mail clientes.
9. **Observação**: ≥ 2h com SLOs estáveis.
10. **Rollover**: decidir permanência ou *fallback*.

### 6.2 `az-failover.md` — Falha de AZ

* Rely em **control plane** gerenciado + **PodDisruptionBudget** + **multi-AZ**.
* Verificar re-balance de **brokers Kafka** e **pools de conexão**.

### 6.3 `partial-restore.md` — Restauração parcial (PITR granular)

* Ex.: usuário removeu OS críticas.
* **Sandbox restore** até *timestamp T*.
* Exportar dados (dump seletivo) e **reaplicar via comandos idempotentes** (evita violar projeções/eventos).

### 6.4 `ransomware-response.md` — Ransomware/Criptografia indevida

1. **Isolar** nós suspeitos (quarentena, revogar credenciais).
2. **Bloquear** rotação de chaves KMS afetadas; auditar acessos.
3. **Verificar** integridade de backups (hash/ETag).
4. **Restaurar** dados a partir de *snapshots imutáveis*; **trocar chaves**.
5. **Reset** de segredos (External Secrets) e **rotate** tokens.
6. **Comms** com clientes e autoridades conforme LGPD/DPIA (Manif. 3).
7. **RCA** com evidências forenses.

### 6.5 `kms-compromise.md` — Comprometimento de chaves KMS

* **Disable**/revoke chaves comprometidas.
* **Re-encrypt** dados com novas KEKs/DEKs (playbook passo-a-passo).
* **Rotate** credenciais de apps e *signed URLs*.

---

## 7) Exercícios e auditoria (`exercises/*`)

### 7.1 `program.md` — Programa de exercícios

* **Mensal**: **PITR** Postgres (sandbox) + checklist de tempos (meta ≤ 30 min).
* **Trimestral**: **Failover regional** em janela controlada (escopo C0).
* **Semestral**: **Ransomware simulado** (restauração limpa, rotação de segredos).
* **Anual**: **BCP completo** (simulação de perda de provedor ou data center).

### 7.2 `scenarios.md` — Cenários

* Perda de AZ, perda de região, corrupção lógica (delete acidental), falha de schema (poison pill), KMS comprometido, saturação de DB, ruptura de rede entre clusters.

### 7.3 `evidence-template.md` — Evidências

* Tabela com **início/fim**, **tempo total**, **RTO obtido**, **RPO medido**, **screenshots/IDs de jobs**, **hashes** de backups, **lições** e **issues** criadas.

---

## 8) Monitoramento e SLO de DR (`monitoring/*`)

### 8.1 `kpis.md`

* **Backup sucesso (%)** por sistema (alvo ≥ 99%).
* **Tempo médio de restauração (RTO real)** por tecnologia.
* **Atraso de replicação** (WAL, MM2 lag, CRR replication time).
* **Test coverage DR**: % de serviços C0/C1 testados em ≤ 90 dias.

### 8.2 `grafana-panels.json` (resumo)

* Paineis: *Backup Success Rate*, *PITR Restore Duration*, *Kafka MM2 Lag*, *WAL Shipping Delay*, *S3 CRR ReplicationAge*, *Runbook Exercises Outcomes*.

### 8.3 `alerting-rules.yaml` (excerto)

```yaml
groups:
  - name: dr
    rules:
      - alert: BackupFailureRate
        expr: (sum(rate(backup_jobs_failed_total[1h])) / sum(rate(backup_jobs_total[1h]))) > 0.05
        for: 15m
        labels: { severity: ticket }
        annotations: { summary: "Falha de backups >5%" }
      - alert: WALShippingDelay
        expr: wal_shipping_delay_seconds > 300
        for: 10m
        labels: { severity: page }
      - alert: KafkaMirrorLagHigh
        expr: kafka_mm2_replication_lag > 120
        for: 10m
        labels: { severity: ticket }
      - alert: S3CRRReplicationAgeHigh
        expr: s3_crr_replication_age_seconds > 1800
        for: 30m
        labels: { severity: ticket }
```

---

## 9) BCP — continuidade de negócio (`bcp/*`)

### 9.1 `process-map.md` — Processos críticos

* **Execução de OS & Apontamentos** (C0)
* **Medição & Faturamento** (C0)
* **Suprimentos (requisições/PO)** (C1)
* **Autenticação & Acesso** (C1)

### 9.2 `manual-workarounds.md` — Contingência manual

* **Apontamentos offline** em planilha padronizada (modelo anexado) com campos mínimos para posterior *ingest*.
* **Regras**: IDs temporários, timestamp UTC, assinatura do responsável.
* **SLA**: ingest em até 24h após restabelecimento.

### 9.3 `vendor-contacts.md`

* Lista de **fornecedores/contatos** (cloud, DNS, CDN, IdP, bancos gerenciados), **SLA contratual** e **procedimento de escalonamento**.

### 9.4 `communication-plan.md`

* Canais internos (Incident Channel), externos (Status Page, e-mail), **mensagens padrão** por severidade (linka Manifesto 9).

---

## 10) IaC de referência (`iac/*`) — excertos

### 10.1 `velero-values.yaml`

```yaml
configuration:
  backupStorageLocation:
    - name: default
      bucket: obraflow-backups
      config: { region: us-east-1, s3ForcePathStyle: "true" }
  volumeSnapshotLocation:
    - name: default
      config: { region: us-east-1 }
schedules:
  daily:
    schedule: "0 3 * * *"
    template:
      ttl: 168h
      includedNamespaces: ["obraflow-data","obraflow-app"]
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

### 10.2 `route53-failover.yaml` (conceito)

```yaml
# Registros primário/secondary com health check (HTTP 200 em /healthz do Gateway)
```

---

## 11) Segurança & LGPD (amarração com Manifesto 3)

* **Imutabilidade** de backups (WORM) para evidências; **expurgo** conforme `ropa.md`.
* **Segurança de chaves** (KMS, rotação, acesso mínimo).
* **DLP** aplicado em restaurações (sanitização antes de ambientes não-prod).
* **Registro** de acesso a dados restaurados (trilha de auditoria).

---

## 12) Governança & Responsabilidades

* **Owner DR/BCP**: Plataforma/SRE.
* **Sponsors**: Produto/Operações.
* **KPIs** revisados em **Operational Review** mensal.
* **Exercícios** com **evidências versionadas** (pull requests com prints e logs).

---

## 13) Definition of Ready / Done (DR/BCP)

**Pronto (Ready)**

* RTO/RPO definidos por serviço.
* Topologia e replicação implementadas.
* Backups monitorados e com **relatórios diários**.

**Concluído (Done)**

* 1 exercício PITR **passado** no último mês.
* 1 exercício **regional failover** nos últimos 90 dias.
* *Runbooks* atualizados após cada exercício.
* Painéis e alertas verdes; **KPIs ≥ alvo**.

---

### Próximos passos sugeridos

1. Validar/ajustar **RTO/RPO** junto aos stakeholders (engenharia, operações, financeiro).
2. Selecionar **região secundária** alvo e habilitar **MM2/CRR** para os tópicos/buckets C0.
3. Agendar **exercício piloto** (PITR Postgres + restore parcial) com evidência oficial.
4. Integrar **KPIs de DR** aos painéis executivos.

Deseja que eu prossiga com o **Manifesto 11 — *FinOps & Cost Governance (Unit Economics, Orçamento por Tenant, Otimização)***, ou prefere ajustes neste DR/BCP?
