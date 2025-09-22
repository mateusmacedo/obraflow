# Manifesto 15 — **Segurança de Plataforma & LGPD Avançado**

*(DPIA, DLP, Chaves & Segredos, Data Residency, Zero-Trust, Supply Chain, Auditoria & Resposta a Incidentes de Privacidade)*

Este pacote define os **controles técnicos e organizacionais** para operar o ObraFlow em conformidade com **LGPD** e boas práticas de **segurança cloud-native**. Conecta-se aos Manifestos 1–14 (SLO, Observabilidade, DR/BCP, FinOps, Data Mesh, AI/ML, etc.).

---

## 📁 Estrutura proposta

```
security-privacy/
  README.md
  governance/
    roles-lgpd.md
    ropa-register.md
    dpia-template.md
    privacy-by-design-checklist.md
    data-classification-policy.md
    data-residency-policy.md
  crypto-keys/
    kms-hierarchy.md
    key-rotation-runbook.md
    envelope-encryption.md
    kms-terraform.tf
  secrets/
    external-secrets/
      values.yaml
      secret-store.yaml
      app-secret.yaml
    sops/
      .sops.yaml
      examples/obraflow.enc.yaml
    vault/
      policies.hcl
      transit-engine.md
  dlp/
    pipelines/
      text-pii-redaction.ts
      image-redactor.py
      sql-sanitizers.sql
    detectors/
      regexes.yaml
      custom-ner.md
    policies/
      dlp-rules.yaml
      index-redaction-flow.md
  access-control/
    authn-authz-arch.md
    oidc-config.md
    abac-policies.rego
    k8s/opa-constraints.yaml
    db/rls-policies.sql
    nest/abac.guard.ts
    go/mtls-spiffe-middleware.go
  network/
    zero-trust.md
    istio/peer-authentication.yaml
    istio/authorization-policy.yaml
    egress-policies.yaml
  supply-chain/
    slsa.md
    cosign-policy.yaml
    sbom/
      syft.yaml
      verify-grype.md
    cicd/secret-scans.yml
  audit-incident/
    audit-logging-spec.md
    tamper-evidence.md
    siem-integration.md
    privacy-incident-runbook.md
    breach-comm-templates.md
```

---

## 1) Governança LGPD

### 1.1 Papéis & Responsabilidades — `governance/roles-lgpd.md`

* **Controlador** (Cliente Enterprise, quando aplicável) / **Operador** (ObraFlow).
* **DPO/Encarregado** (contato oficial e coordenação com ANPD).
* **Data Owner** por domínio (work, supply, identity).
* **Segurança/AppSec/SRE**: implementação técnica, *threat modeling*, avaliação de riscos.

### 1.2 Registro de Operações (RoPA) — `governance/ropa-register.md`

Modelo tabular (processo, finalidades, bases legais, categorias de dados, retenção, compartilhamentos, controles).

### 1.3 DPIA (Relatório de Impacto) — `governance/dpia-template.md` *(trecho)*

```markdown
# DPIA — <Processamento/Feature>
Finalidade e base legal:
Categorias de titulares e dados:
Fluxo de dados (coleta → processamento → armazenamento → compartilhamento):
Riscos (confidencialidade, integridade, disponibilidade, reidentificação):
Controles aplicados (técnicos/organizacionais):
Medidas de mitigação e plano de ação:
Data Residency & transferências internacionais:
Avaliação residual de risco:
Aprovação (DPO, Segurança, Jurídico):
```

### 1.4 Privacy by Design — `privacy-by-design-checklist.md`

* Minimização (dados estritamente necessários).
* **Pseudonimização** em *Silver/Gold* (Manif. 13).
* **Opt-out** para treinos/feedback de IA (Manif. 12).
* **Retenção/Expurgo** com lifecycle automatizado.

---

## 2) Criptografia, Chaves e Rotação

### 2.1 Hierarquia de KMS — `crypto-keys/kms-hierarchy.md`

* **KEK** por ambiente (dev/hml/prd) e por domínio sensível (identity, billing).
* **DEK** por serviço/tenant (envelope encryption).
* Chaves de **assinatura** separadas das de **sigilo** (cryptographic separation).
* Uso de **AWS KMS/Cloud KMS** + **client-side envelope** para campos críticos.

### 2.2 Envelope Encryption (aplicação) — `crypto-keys/envelope-encryption.md`

Fluxo: gerar DEK → cifrar dado → armazenar `ciphertext` + `dek_ref` → DEK cifrada pelo KEK no KMS → **rotacionar KEK** com *reencrypt* periódico.

### 2.3 Terraform (exemplo de KEK) — `crypto-keys/kms-terraform.tf`

```hcl
resource "aws_kms_key" "obraflow_prd_data" {
  description             = "KEK - ObraFlow PRD data"
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"
  customer_master_key_spec= "SYMMETRIC_DEFAULT"
  policy = file("kms-policy.json")  # least-privilege por serviço
  tags = { "env" = "prd", "system" = "obraflow" }
}
```

### 2.4 Rotação — `key-rotation-runbook.md`

* **Automática** (KMS) anual para KEKs.
* **DEKs** por ciclo de 90 dias ou invalidação no *kill switch*.
* Playbook para **comprometimento** (ver Manif. 10: `kms-compromise.md`).

---

## 3) Gestão de Segredos

### 3.1 External Secrets (K8s) — `secrets/external-secrets/secret-store.yaml`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata: { name: aws-secrets, namespace: obraflow-app }
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth: { jwt: { serviceAccountRef: { name: es-sa } } }
```

`secrets/external-secrets/app-secret.yaml`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: { name: bff-secrets, namespace: obraflow-app }
spec:
  refreshInterval: 1h
  target: { name: bff-env, template: { metadata: { labels: { obraflow.io/component: bff }}}}
  data:
    - secretKey: LLM_API_KEY
      remoteRef: { key: obraflow/prd/ai-gateway, property: apiKey }
```

### 3.2 SOPS + Git-Ops — `secrets/sops/.sops.yaml`

```yaml
creation_rules:
  - kms: "arn:aws:kms:us-east-1:111:key/abcd-efgh"
    encrypted_regex: '^(data|stringData)$'
    path_regex: '.*\.enc\.yaml$'
```

> **Política**: nenhum segredo em texto puro no repositório; *pre-commit hooks* + *scanners* (gitleaks/truffleHog) no CI.

### 3.3 Vault (opcional)

* **Transit Engine** para **encryption-as-a-service** (offloading de criptografia).
* Policies HCL restritas a *namespaces* e aplicações.

---

## 4) DLP (Prevenção de Perda de Dados)

### 4.1 Regras & Detectores — `dlp/detectors/regexes.yaml`

```yaml
patterns:
  cpf:      '\b\d{3}\.\d{3}\.\d{3}\-\d{2}\b'
  cnpj:     '\b\d{2}\.\d{3}\.\d{3}\/\d{4}\-\d{2}\b'
  email:    '\b[\w\.-]+@[\w\.-]+\.\w+\b'
  phone_br: '\b\(?\d{2}\)?\s?\d{4,5}\-?\d{4}\b'
actions:
  - redact
  - hash(salt=env:DLP_SALT)
```

### 4.2 Pipeline de Redação (texto) — `dlp/pipelines/text-pii-redaction.ts`

```ts
export function redactPII(text: string, rules: RegExp[]): string {
  return rules.reduce((acc, rx) => acc.replace(rx, m => `<REDACTED:${rx.source.slice(2,5)}>`), text);
}
// Uso: antes de indexar docs no RAG (Manif. 12) e ao logar campos livres.
```

### 4.3 Redação de Imagens — `dlp/pipelines/image-redactor.py`

```python
# borra rostos/placas; remove metadados EXIF
```

### 4.4 SQL Sanitizers — `dlp/pipelines/sql-sanitizers.sql`

```sql
update rag_docs set content = regexp_replace(content, '\b[\w\.-]+@[\w\.-]+\.\w+\b', 'EMAIL_REDACTED', 'g');
```

> **Obrigatório**: DLP no **ingest** (bronze) e **pré-indexação** para IA (Manif. 12).

---

## 5) Data Residency & Geo-Fencing

### 5.1 Política — `governance/data-residency-policy.md`

* **Residência primária**: dados de clientes brasileiros residem em **região BR ou LATAM** quando viável; transferências internacionais requerem **garantias contratuais** e **DPIA**.
* **Segregação lógica** por **tenant/obra** (labels, schemas, buckets) e **RLS** no *warehouse*.

### 5.2 Marcação de recursos (geo) — exemplos

* Buckets: `obraflow-data-prd-br/*`; replicação CRR controlada (Manif. 10).
* Tabelas *Iceberg*: partição por `tenant_id` e `region`.

### 5.3 Enforcements (app + rede)

* **ABAC** em BFF/serviços: negar acesso quando `user.region != resource.region`.
* **NetworkPolicies/ServiceMesh**: bloquear egress a endpoints fora de regiões autorizadas.

---

## 6) Autenticação, Autorização & Zero-Trust

### 6.1 OIDC & Escopos — `access-control/oidc-config.md`

* **PKCE** para mobile/web; **mTLS** para *service-to-service*.
* **Claims**: `tenant`, `site`, `role`, `region`, `scopes`.
* Sessão curta + **refresh rotation**; *device binding* para mobile.

### 6.2 ABAC (OPA/Rego) — `access-control/abac-policies.rego`

```rego
package obraflow.authz

default allow = false
allow {
  input.user.tenant == input.resource.tenant
  input.user.role == "engineer"
  input.action == "read"
}
allow {
  input.user.role == "admin"
}
deny { input.resource.region != input.user.region }
```

### 6.3 OPA Constraints (K8s) — `access-control/k8s/opa-constraints.yaml`

Enforce: sem *LoadBalancer* público por padrão, *egress* limitado, labels obrigatórios (Manif. 6 & 11).

### 6.4 RLS no banco — `access-control/db/rls-policies.sql`

```sql
CREATE POLICY rls_tenant ON gold.work_orders
USING (tenant_id = current_setting('app.tenant_id'));
```

### 6.5 NestJS ABAC Guard — `access-control/nest/abac.guard.ts`

```ts
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
@Injectable()
export class AbacGuard implements CanActivate {
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const { tenant, role, region } = req.user ?? {};
    const res = req.resource ?? {};
    if (!tenant || tenant !== res.tenant) return false;
    if (region && res.region && region !== res.region) return false; // geo-fencing
    return role === 'engineer' || role === 'admin';
  }
}
```

### 6.6 Go mTLS + SPIFFE — `access-control/go/mtls-spiffe-middleware.go`

```go
// valida SPIFFE ID spiffe://obraflow/<svc> e extrai atributos para ABAC
```

### 6.7 Service Mesh (Istio)

`network/istio/peer-authentication.yaml`

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata: { name: default, namespace: obraflow-app }
spec: { mtls: { mode: STRICT } }
```

`network/istio/authorization-policy.yaml`

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata: { name: bff-allow, namespace: obraflow-app }
spec:
  selector: { matchLabels: { app: bff } }
  rules:
    - from: [{ source: { principals: ["spiffe://obraflow/ai-gateway"] } }]
      to: [{ operation: { methods: ["GET","POST"], paths: ["/api/*"] } }]
```

---

## 7) Segurança da Cadeia de Suprimentos (Supply Chain)

### 7.1 Assinatura & Policy — `supply-chain/cosign-policy.yaml`

* **cosign** para assinar imagens; recusa de deploy sem assinatura válida.
* **Rekórd**/transparência pública opcional.

### 7.2 SBOM & Scans — `supply-chain/sbom/syft.yaml`, `verify-grype.md`

* Gerar **SBOM** (Syft) por imagem; verificar **CVEs** (Grype/Trivy).
* **Gate CI**: bloquear **CRITICAL/HIGH** (Manif. 7/8).

### 7.3 SLSA — `supply-chain/slsa.md`

* Objetivo **SLSA L3**: builds reprodutíveis, provenance assinada, *ephemeral runners*.

### 7.4 CI — segredos & credenciais — `supply-chain/cicd/secret-scans.yml`

* *Secret scanning* + *commit signing* (GPG/Sigstore).
* **Branch protection** e **PR approvals**.

---

## 8) Auditoria, Imutabilidade & SIEM

### 8.1 Especificação de auditoria — `audit-incident/audit-logging-spec.md`

* **Quem** (sub), **O quê** (ação/recurso), **Quando** (ts), **Onde** (ip/device), **Contexto** (tenant/site), **Resultado**.
* **Correlações** com `correlation_id` (Manif. 4).

### 8.2 Prova de não-alteração — `audit-incident/tamper-evidence.md`

* **Hash encadeado** por lote (Merkle) + **assinatura** (KMS) armazenada em bucket WORM (Manif. 10).
* Rotina de **verificação** periódica.

### 8.3 Integração SIEM — `audit-incident/siem-integration.md`

* Normalização (CEF/OTLP), retenção, regras de detecção (login anômalo, acesso cross-region, *role escalation*).

---

## 9) Incidente de Privacidade & Notificações

### 9.1 Runbook — `audit-incident/privacy-incident-runbook.md`

1. **Conter** (isolar credenciais/hosts, desabilitar tokens).
2. **Avaliar** escopo, categorias de dados, titulares afetados, riscos.
3. **Notificar** *stakeholders* internos; preparar comunicação a clientes e **autoridade reguladora** conforme diretrizes vigentes e contrato.
4. **Evidências** preservadas; **RCA blameless** (Manif. 9).
5. **Correções** e **hardening**; atualização de DPIA/RoPA.

> *Nota:* Prazos e formatos de notificação a autoridades e titulares variam por caso e orientação regulatória. Defina no contrato/Politica de Privacidade os **canais** e **janelas** de notificação.

### 9.2 Templates — `audit-incident/breach-comm-templates.md`

* Comunicado a clientes (resumo, medidas, ações do titular).
* FAQ interno para suporte e CS.

---

## 10) Integrações com Manifestos anteriores

* **Manif. 3 (Segurança/LGPD base):** amplia DLP, RLS, retenção, DPIA e governança.
* **Manif. 4 (Observabilidade):** auditoria e métricas de segurança expostas; alertas no stack.
* **Manif. 6 (Infra/GitOps):** OPA/Gatekeeper, External Secrets, políticas de rede/mesh.
* **Manif. 10 (DR/BCP):** chaves/segredos em rotação e cenários de KMS comprometido.
* **Manif. 12 (AI/ML):** DLP pré-indexação, guardrails, *opt-out*, *kill switch* de features de IA.
* **Manif. 13–14 (Dados & BI):** RLS/CLS, data residency, linhagem e *privacy metrics* (incidentes, solicitações de titulares, % dados pseudonimizados).

---

## 11) Definition of Ready / Done (Segurança & LGPD)

**Ready**

* RoPA inicial criado; *DPIA template* vigente; classificação de dados definida.
* KMS/External Secrets implantados; *secret scanning* no CI.
* OPA/Gatekeeper com *baseline* de políticas; auditoria ativada.

**Done**

* DLP em ingest e IA; **RLS** e **geo-fencing** aplicados.
* Imagens assinadas e **SBOM** verificado em produção; *policy controller* bloqueando artefatos não conformes.
* **Runbook** de incidente de privacidade testado (tabletop).
* **Relatórios** de auditoria e **métricas** de privacidade nos painéis executivos.

---

## Próximos passos sugeridos

1. Publicar a **política de data residency** e ajustar rotas/egress conforme regiões alvo.
2. Ativar **assinatura de imagens** (cosign) e **enforcement** em admission controller.
3. Integrar **DLP** ao pipeline de documentação técnica/RAG e aos *logs de campo livre*.
4. Executar um **tabletop exercise** de incidente de privacidade e registrar evidências.

Se estiver de acordo, posso seguir com o \*\*Manifesto 16 — *Compliance & Controles (ISO 27001, SOC 2, ANPD – evidências e automações)* \*\*, ou deseja ajustes neste Manifesto 15 antes?
