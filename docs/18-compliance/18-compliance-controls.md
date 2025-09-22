# Manifesto 16 — **Compliance & Controles**

*(ISO/IEC 27001:2022, SOC 2, ANPD — evidências, auditoria contínua e automações)*

Este manifesto de compliance foi **integrado com os padrões técnicos** definidos no plano de ação do monorepo, garantindo alinhamento entre arquitetura, desenvolvimento e operações. Estabelece a **governança de controles**, **coleta de evidências** e **auditoria contínua** do ObraFlow, conectando-se aos Manifestos 1–15 (segurança, dados, DR/BCP, FinOps, AI/ML, etc.).

---

## 📁 Estrutura proposta (monorepo de compliance)

```
compliance/
  README.md
  governance/
    policy-hub.md
    isms-scope.md
    risk-register.md
    statement-of-applicability.md
    supplier-management.md
    roles-raci.md
  frameworks/
    iso27001/
      annexA-mapping.yaml
      controls-implementation.md
      audits/plan-iso-annual.md
    soc2/
      trust-services-criteria.yaml
      controls-soc2.md
      audits/plan-soc2.md
    anpd/
      lgpd-mapping.yaml
      dpia-index.md
      incident-reporting.md
  controls/
    catalog.yaml
    owners.yaml
    tests/
      conftest-policies/         # OPA/Rego p/ IaC & K8s
      inspec-profiles/           # CIS/OS hardening
      tfsec-rules/               # IaC scanning custom
      aws-config-rules/          # Config/GuardDuty/CloudTrail
      gcp-policies/              # Equivalentes GCP
  evidence/
    collectors/
      aws-config-export.yml
      k8s-snapshots.sh
      github-actions-logs.yml
      argocd-audit-pull.sh
      s3-worm-proof.md
    storage/
      README.md
      retention-policy.md
      evidence-index.json
  automation/
    continuous-controls.yml
    policy-as-code-pr.yml
    change-control-workflow.yml
    evidence-signer.sh
  audits/
    internal-audit-plan.md
    checklist-fieldwork.md
    corrective-actions-register.md
  metrics/
    kpis-kras.md
    dashboards.json
```

---

## 1) **Âmbito, Política e Governança**

### 1.1 ISMS — `governance/isms-scope.md`

* **Escopo**: serviços cloud-native (K8s, dados, AI Gateway, Data Platform), ambientes **dev/hml/prd** e funções de apoio.
* **Contexto**: partes interessadas (clientes, fornecedores cloud, regulador), requisitos (contratuais, LGPD).

### 1.2 Hub de Políticas — `governance/policy-hub.md`

* Políticas **matriciadas** ao Anexo A (ISO), **TSC** (SOC 2) e **LGPD/ANPD**, com links para manifestos anteriores:

  * Segurança, acesso, gestão de mudanças, backup, continuidade, privacidade, desenvolvimento seguro, resposta a incidentes, fornecedores.

### 1.3 RACI — `governance/roles-raci.md`

* **Compliance Lead** (A), **CISO/Sec** (R), **SRE/Plataforma** (R), **Jurídico/DPO** (C), **Produto/Engenharia** (C), **Diretoria** (I).

---

## 2) **Catálogo de Controles & Mapeamento**

### 2.1 Catálogo — `controls/catalog.yaml`

```yaml
controls:
  - id: A.5.1
    name: Policies for information security
    framework: ISO27001-AnnexA
    objective: "Estabelecer políticas e revisão anual"
    owner: governance
    evidence: ["policy-hub.md", "approval-records/2025-01"]
    automated: false
  - id: A.8.16
    name: Monitoring activities
    framework: ISO27001-AnnexA
    objective: "Monitorar eventos e alertas de segurança"
    owner: sre
    evidence: ["observability/alerting-rules.yaml", "grafana-screenshots/*"]
    automated: true
  - id: CC6.1
    name: Logical access security
    framework: SOC2
    objective: "Autorização baseada em papéis/atributos"
    owner: platform
    evidence: ["access-control/abac-policies.rego", "rbac-export.json"]
    automated: true
  - id: LGPD-SEC-INC
    name: Incidente de privacidade
    framework: ANPD
    objective: "Runbook e notificações"
    owner: dpo
    evidence: ["audit-incident/privacy-incident-runbook.md","tabletop-logs/*"]
    automated: partial
```

### 2.2 Mapeamentos

* **ISO/IEC 27001:2022 Anexo A → controles técnicos** (OPA, Istio, External Secrets).
* **SOC 2 TSC (CC, A1, C1, PI1…)**:

  * **CC2** (Comunicação) → catálogos e painéis de segurança;
  * **CC6** (Acesso) → OIDC, ABAC, RLS;
  * **CC7** (Monitoramento) → SIEM/alertas;
  * **CC8** (Mudança) → GitOps, CAB leve, release gates.
* **ANPD/LGPD**: base legal, RoPA, DPIA, incidentes, direitos do titular (listas e endpoints, Manif. 15).

---

## 3) **EvidenceOps** (coleta e retenção de evidências)

### 3.1 Armazenamento & Cadeia de Custódia — `evidence/storage/README.md`

* **Bucket WORM** (bloqueio de objeto) + **hash encadeado** e **assinatura KMS** dos pacotes (ver `tamper-evidence.md` do Manif. 15).
* **Retenção**: mínimo **12 meses** (SOC 2) / conforme contrato; index **`evidence-index.json`** para trilha.

### 3.2 Coletores padronizados — `evidence/collectors/*.yml`

`aws-config-export.yml` (ex.)

```yaml
name: aws-config-export
schedule: "0 */6 * * *"
steps:
  - aws-config: { regions: ["us-east-1","sa-east-1"], resources: ["IAM","EC2","S3","KMS","RDS","EKS"] }
  - save: s3://obraflow-evidence/aws-config/{{timestamp}}.json
  - sign: kms://alias/obraflow-evidence
```

`k8s-snapshots.sh` (trecho)

```bash
kubectl get ns,deploy,svc,ing,networkpolicy -A -o yaml > k8s-state-$(date -Iminutes).yaml
cosign sign-blob --key awskms://alias/obraflow-evidence k8s-state-*.yaml > k8s-state.sig
```

`github-actions-logs.yml`: exporta logs de pipelines críticos (release, security scans).

---

## 4) **Policy-as-Code** (gates de conformidade)

### 4.1 PR Gate — `automation/policy-as-code-pr.yml`

```yaml
name: Compliance Gates
on: [pull_request]
jobs:
  policies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: IaC Scan (tfsec + custom)
        run: tfsec --format json --out tfsec.json infra/
      - name: OPA Conftest (K8s/Helm)
        run: conftest test charts/ -p compliance/controls/tests/conftest-policies
      - name: Secrets Scan
        run: gitleaks detect --no-banner --report-format json --report-path gitleaks.json
      - name: Evidence Bundle
        run: bash compliance/automation/evidence-signer.sh pr-${{ github.event.pull_request.number }}
```

### 4.2 Exemplo de regra **OPA/Rego** — `controls/tests/conftest-policies/k8s.rego`

```rego
package kubernetes.security

deny[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot
  msg := sprintf("Deployment %s sem runAsNonRoot", [input.metadata.name])
}

deny[msg] {
  input.kind == "Ingress"
  input.spec.tls == null
  msg := sprintf("Ingress %s sem TLS", [input.metadata.name])
}
```

### 4.3 InSpec (CIS) — `controls/tests/inspec-profiles/cis-eks/controls/*.rb`

* Testes de hardening: audit log do control-plane, encryption at rest EKS, restrição de privilégios.

---

## 5) **Auditoria Contínua de Controles**

### 5.1 Pipeline — `automation/continuous-controls.yml`

```yaml
name: Continuous Controls
on:
  schedule: [{ cron: "0 */12 * * *" }]
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AWS Config Rules Export
        run: make export-aws-config
      - name: Query SIEM for last 12h detections
        run: ./scripts/siem-export.sh > evidence/siem-$(date -Ihours).json
      - name: Generate Control KPIs
        run: node scripts/controls-kpi.js > metrics/controls.json
      - name: Sign & Upload
        run: ./compliance/automation/evidence-signer.sh controls-$(date -Ihours)
```

### 5.2 KPIs/Metas — `metrics/kpis-kras.md`

* **Cobertura de controles automatizados** ≥ **70%**.
* **Tempo médio de evidência** (coleta→assinatura) ≤ **15 min**.
* **Não conformidades abertas** ≤ **5** (prioridade alta).
* **Taxa de aprovação em gates de PR** ≥ **95%**.

---

## 6) **Risco & SoA (Statement of Applicability)**

### 6.1 Registro de Riscos — `governance/risk-register.md`

```markdown
| ID | Risco | Prob. | Impacto | Nível | Tratamento | Owner | Controles | Prazo |
|----|-------|-------|---------|-------|------------|-------|-----------|-------|
| R-12 | Vazamento via repo | M | A | Alto | Secret scanning + SOPS + revisão | AppSec | CC6.1, A.8.24 | 2025-10-15 |
```

### 6.2 SoA — `governance/statement-of-applicability.md`

* Lista de **controles aplicáveis**, justificativa de exclusões, status de implementação, **evidências vinculadas**.

---

## 7) **Gestão de Mudanças & Fornecedores**

### 7.1 Mudanças — `automation/change-control-workflow.yml`

* Amarra **Manifesto 8** (Release/CAB leve): PRs com *risk tag* exigem **aprovador de compliance** e **evidência** anexada.

### 7.2 Fornecedores — `governance/supplier-management.md`

* Due diligence (ISO/SOC, *pen test*), **DPA** (Data Processing Addendum), cláusulas LGPD/ANPD, **monitoramento de conformidade** (renovação anual).

---

## 8) **Planos de Auditoria**

### 8.1 ISO 27001 (Interna & Certificação) — `frameworks/iso27001/audits/plan-iso-annual.md`

* **Ciclo PDCA** do ISMS; auditorias internas por **domínio** (A.5–A.8).
* Amostragens: acessos, mudanças, incidentes, backups/DR, fornecedores.

### 8.2 SOC 2 Type I/II — `frameworks/soc2/audits/plan-soc2.md`

* **Type I** (design) → **Type II** (operacional, 6–12 meses).
* TSC: **Security** obrigatório; **Availability/Confidentiality** recomendados.

### 8.3 ANPD/LGPD — `frameworks/anpd/incident-reporting.md`

* Procedimento e **prazos** internos para avaliação e eventual notificação (ligado ao Manif. 15).

---

## 9) **Métricas & Painéis**

### 9.1 Painéis — `metrics/dashboards.json`

* **Conformidade por controle** (verde/amarelo/vermelho),
* **Evidências por período** (coletas/assinadas),
* **Gates de PR** (falhas por tipo: OPA, tfsec, segredos),
* **Tempo de resposta a achados** (SLA de correção).

---

## 10) **Integrações com Manifestos 1–15**

* **Manif. 6/8**: GitOps + gates → **Change Management** (SOC2 CC8).
* **Manif. 4/15**: SIEM, auditoria, DLP → **Monitoring/Privacy** (CC7/LGPD).
* **Manif. 10**: DR/BCP → **Availability** (SOC2 A1; ISO A.5/A.8).
* **Manif. 11**: evidências de FinOps (orçamentos/alertas) para **governança**.
* **Manif. 12–14**: RAG/BI com **RLS/CLS**, DPIA, catálogos e linhagem como evidências.

## 10.1) Integração com Padrões do Monorepo

### Estrutura de Compliance Aplicada
```
obraflow/
├── libs/
│   ├── ts/compliance/            # Controles TypeScript
│   ├── ts/audit/                 # Auditoria e evidências
│   └── go/pkg/compliance/        # Controles Go
├── tools/
│   ├── generators/compliance/    # Scaffolds de controles
│   └── scripts/compliance/       # Scripts de auditoria
└── .github/workflows/
    ├── compliance-scan.yml       # Verificação de controles
    └── evidence-collect.yml      # Coleta de evidências
```

### Padrões Técnicos Integrados
- **DDD**: Controles organizados por domínio (Security, Privacy, Operations)
- **CQRS+EDA**: Separação entre auditoria e compliance
- **Clean Architecture**: Camadas de evidências e controles
- **Multi-tenant**: Segmentação por tenant/obra nos controles
- **Observabilidade**: Métricas de compliance e auditoria

---

## 11) **Definition of Ready / Done (Compliance)**

**Ready**

* **Catálogo de controles** e **owners** definidos.
* **Gates** de PR ativos (OPA, tfsec, secrets).
* **Coleta de evidências** com assinatura KMS funcionando.

**Done**

* **SoA** publicado; **riscos** priorizados e planos de ação.
* **Auditoria contínua** executando (cron) e **painéis** publicados.
* **Plano de auditoria** (ISO/SOC2) aprovado; **tabletop** de incidente de privacidade concluído.
* **≥70%** dos controles com **evidência automática**.

---

## Próximos passos sugeridos

1. Nomear **owners** por controle (preencher `owners.yaml`) e aprovar o **SoA**.
2. Ativar **policy-as-code** em todos os repositórios e configurar **EvidenceOps** (bucket WORM + assinatura).
3. Rodar **auditoria interna piloto** (2 áreas) e registrar **ações corretivas**.
4. Agendar **gap assessment** para **SOC 2 Type I** e planejar janelas de amostragem.

Se desejar, posso montar um **checklist operacional** de 30 dias para colocar este Manifesto 16 em produção (passo-a-passo com donos e artefatos).
