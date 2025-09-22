# Aceleração com **AdminLTE 3 React** + **Strapi** + **Node-RED**

*(arquitetura, responsabilidades, integrações, segurança, exemplos de código e plano 30-60-90)*

> Objetivo: reduzir **time-to-market** do ObraFlow criando um **Backoffice** pronto (AdminLTE React), **CRUDs e Catálogos** (Strapi) e **automações/integrações low-code** (Node-RED), sem abandonar DDD, SLOs, segurança e governança definidos nos Manifestos.

---

## 1) Papéis no ecossistema

* **AdminLTE 3 React** (Backoffice Web):
  Painéis administrativos, cadastros de apoio, gestão operacional e configurações—com layout responsivo, componentes prontos e navegação padrão. Excelente para **MVP** e áreas internas (Gestão de OS, Materiais, Equipes, Permissões).

* **Strapi** (Headless CMS/API Builder):
  CRUD de **domínios não críticos** e catálogos (Materiais, Fornecedores, Tipologias, Checklists), **ConfigCenter** (flags/parametrizações por tenant/obra) e **conteúdo operacional** (manuais, POPs, comunicados). Emite **webhooks** para o bus/event mesh e valida campos com políticas.

* **Node-RED** (iPaaS low-code):
  Orquestrações rápidas: **webhooks↔serviços**, ETL leve, **agendamentos**, integrações com SaaS (e-mail, chat, planilhas), **IoT** (edge), e **prototipação de fluxos** que depois podem ser “graduados” para microserviços.

> Regra de ouro (DDD): *Core domain* (Work Mgmt, Medição, Alocação) permanece nos **serviços de backend** e contratos governados (Manifestos 2/5). Strapi/Node-RED aceleram a **parte de borda** e configuração.

---

## 2) Arquitetura de referência (visão macro)

```
[AdminLTE React (Backoffice)]
      |  (JWT OIDC, RBAC)
      v
[BFF/API Gateway] ——> [Serviços Core (Work, Measurement, Supply)]
      |                         |        \
      |                         |         > [Event Bus (Kafka)]
      |                         |                       ^
      v                         v                       |
[Strapi Headless CMS] ——webhooks/REST——> [Node-RED Flows]—┘
   |   (Catálogos, Docs,         | (transformação, ETL leve, agendamentos,
   |    Config Center, RBAC)     |  conectores SaaS/IoT, “quick automations”)
   v
[Storage S3/DB + RLS]
```

* **Backoffice** consome BFF e algumas APIs Strapi; **Node-RED** recebe webhooks do Strapi, normaliza e publica no **event bus**; serviços core assinam/produzem eventos.
* **Segurança**: OIDC (SSO), RLS por tenant/site nos dados, mTLS service-to-service (mesh).
* **GitOps**: tudo empacotado em Helm/ArgoCD, com pipelines de testes (Manifesto 7) e *release gates* (Manifesto 8).

---

## 3) AdminLTE 3 React — padrões e exemplos

### 3.1 Boas práticas

* **Autenticação**: OIDC/OAuth2 (PKCE). Ao logar, obter `id_token`/`access_token` e *claims* (`tenant`, `role`, `site`).
* **RBAC/ABAC**: Guardar claims no **AuthContext**; HOCs/RouteGuards por **role/tenant**.
* **Data-fetching**: React Query (cache, retry, invalidação por `etag`).
* **Observabilidade**: interceptors HTTP com **correlation-id**, logging e métricas (latência, erro).
* **Design System**: utilizar componentes AdminLTE (cards, tables, forms) + estilos consistentes.
* **i18n**: chaves para PT-BR/EN.

### 3.2 Esqueleto de página (lista+form de Materiais)

```tsx
// src/pages/materials/MaterialsPage.tsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Card, CardBody } from 'adminlte-3-react'; // lib do template
import { useAuth } from '@/auth/AuthContext';
import { api } from '@/infra/http';

type Material = { id: string; sku: string; name: string; unit: string; status: 'ACTIVE'|'INACTIVE' };

export default function MaterialsPage() {
  const { accessToken, tenant } = useAuth();
  const qc = useQueryClient();

  const list = useQuery({
    queryKey: ['materials', tenant],
    queryFn: async () => (await api.get(`/strapi/materials?tenant=${tenant}`, { headers: { Authorization: `Bearer ${accessToken}`}})).data as Material[]
  });

  const create = useMutation({
    mutationFn: async (m: Omit<Material,'id'>) =>
      (await api.post(`/strapi/materials`, { ...m, tenant }, { headers: { Authorization: `Bearer ${accessToken}`}})).data,
    onSuccess: () => qc.invalidateQueries({ queryKey: ['materials', tenant] })
  });

  return (
    <Card>
      <CardBody>
        <h3 className="mb-3">Materiais</h3>
        {list.isLoading ? 'Carregando…' : (
          <table className="table table-striped">
            <thead><tr><th>SKU</th><th>Nome</th><th>Unidade</th><th>Status</th></tr></thead>
            <tbody>
              {(list.data ?? []).map(m => <tr key={m.id}><td>{m.sku}</td><td>{m.name}</td><td>{m.unit}</td><td>{m.status}</td></tr>)}
            </tbody>
          </table>
        )}
        {/* Form simplificado (ex.: modal) */}
        {/* onSubmit => create.mutate({sku, name, unit, status:'ACTIVE'}) */}
      </CardBody>
    </Card>
  );
}
```

> **Motivo**: AdminLTE entrega UI ágil; React Query garante **testabilidade** e **observabilidade** (falhas, cache, retries), alinhado ao Manifesto 7.

---

## 4) Strapi — modelos, políticas, webhooks

### 4.1 Onde usar o Strapi

* **Catálogos**: Materiais, Fornecedores, Tipos de OS, Checklists, Tabelas de produtividade.
* **Conteúdo**: Manuais, POPs, comunicados (consumidos pelo Copiloto, Manif. 12).
* **Config Center**: parâmetros por `tenant/site` (limites, *feature flags* de UX, textos legais).
* **Rascunhos (draft)**: área para conteúdo em revisão, com **workflows**.

### 4.2 Exemplo de schema (Materiais) – Strapi `content-types/materials/schema.json`

```json
{
  "kind": "collectionType",
  "collectionName": "materials",
  "info": { "singularName": "material", "pluralName": "materials", "displayName": "Materials" },
  "options": { "draftAndPublish": true },
  "attributes": {
    "tenant": { "type": "string", "required": true },
    "sku":    { "type": "string", "unique": true, "required": true },
    "name":   { "type": "string", "required": true },
    "unit":   { "type": "enumeration", "enum": ["m2","m3","kg","un"], "required": true },
    "status": { "type": "enumeration", "enum": ["ACTIVE","INACTIVE"], "default": "ACTIVE" }
  }
}
```

### 4.3 RBAC/policies multi-tenant (Strapi `./src/policies/tenant-policy.js`)

```js
module.exports = (policyContext, config, { strapi }) => {
  const tenant = policyContext.state.user?.tenant;
  const reqTenant = policyContext.request.query?.tenant || policyContext.request.body?.data?.tenant;
  if (!tenant || tenant !== reqTenant) return false; // nega acesso cruzado
  return true;
};
```

### 4.4 Webhooks → Node-RED (Strapi `./config/server.js`)

```js
module.exports = ({ env }) => ({
  webhooks: {
    populateRelations: true,
    defaultHeaders: { 'x-signature': env('WEBHOOK_SECRET') }
  }
});
```

> Configure um **webhook “afterCreate/afterUpdate”** para `/flows/materials` (Node-RED), assinando payload.

---

## 5) Node-RED — fluxos prontos e “graduáveis”

### 5.1 Casos típicos

* **Receber webhooks** do Strapi, normalizar e publicar em **Kafka**/REST do BFF.
* **Agendar** sincronizações (ex.: nightly export p/ data lake).
* **Integrações** com SaaS (e-mail, chat, drive) e **IoT** (telemetria de canteiro).
* **Prototipar** automações (aprovação de fornecedor, fluxo de revisão de POP), com telemetria e *feature flag*.

### 5.2 Exemplo de Flow (webhook → POST no BFF → Kafka)

```json
[
  { "id":"in", "type":"http in", "z":"main", "name":"Strapi Materials", "url":"/flows/materials", "method":"post" },
  { "id":"sig", "type":"function", "z":"main", "name":"Verify Signature", "func":
    "const sig = msg.req.headers['x-signature'];\n// TODO: verificar HMAC (WEBHOOK_SECRET)\nif(!sig) return (msg.res.statusCode=401, msg.res.end('no sig'));\nreturn msg;" },
  { "id":"tx", "type":"function", "z":"main", "name":"Transform",
    "func":"const m=msg.payload;\nmsg.headers={'Content-Type':'application/json'};\nmsg.payload=JSON.stringify({tenant:m.tenant, sku:m.sku, name:m.name, unit:m.unit, ts:Date.now()});\nreturn msg;" },
  { "id":"post", "type":"http request", "z":"main", "name":"BFF Upsert",
    "method":"POST", "ret":"txt", "url":"http://bff.obraflow.svc.cluster.local/api/materials/upsert" },
  { "id":"kfk", "type":"kafka out", "z":"main", "name":"Kafka Topic", "topic":"supply.materials.v1", "broker":"kafka:9092" },
  { "id":"ok", "type":"http response", "z":"main", "name":"200" },
  { "id":"in","wires":[["sig"]]},{"id":"sig","wires":[["tx"]]},{"id":"tx","wires":[["post","kfk"]]},{"id":"post","wires":[["ok"]]}
]
```

> **Observabilidade**: adicione nós de **metric/Prometheus** (latência, 2xx/5xx, retries) e **trace/correlation-id** (header).

---

## 6) Segurança, LGPD e Operação

* **OIDC** em Backoffice e Strapi Admin; **ABAC/RBAC** em BFF e policies no Strapi.
* **Assinatura** de webhooks (HMAC) + **mTLS** no tráfego interno (mesh).
* **DLP**: redigir PII antes de indexar no RAG (Manif. 12); sanitizar campos ricos do Strapi.
* **RLS** em leituras analíticas (Manif. 13/14).
* **Backups/DR**: Strapi DB e uploads com **PITR/CRR** (Manif. 10).
* **FinOps**: quotas e *HPA* para Node-RED; *rollups* de custo por fluxo (Manif. 11).
* **Release**: promover AdminLTE/Strapi/Node-RED via ArgoCD; **canary** e **freeze por SLO** (Manif. 8).

---

## 7) DevEx — *Bootstrap* local com Docker Compose (resumo)

```
docker-compose.yml
  strapi: DB Postgres + uploads (minio)
  nodered: porta 1880, volumes persistentes, nó kafka/http/cron
  bff-mock: endpoints fake para desenvolvimento
  adminlte: Vite dev server (5173)
```

Scripts:

* `make seed-strapi` (catálogos de exemplo)
* `make flows-import` (flows Node-RED versionados)
* `make tunnel-oidc` (OIDC local com Auth0/Keycloak)

---

## 8) Quando **não** usar / limites

* **Core domain crítico** (Work/Medição/Alocação em tempo real) → **serviços próprios** (NestJS/Go) com contratos e testes robustos.
* **Transações complexas** e invariantes fortes → evite CRUD direto em Strapi.
* **Automação de missão crítica** → prototipe no Node-RED, depois **gradue** para microserviço (código versionado, SLAs, testes).

---

## 9) Plano 30-60-90 (enxuto e objetivo)

**0–30 dias**

* Provisionar **Strapi** + **Node-RED** + **AdminLTE** em DEV via Helm.
* Modelar **Materiais, Fornecedores, Checklists** no Strapi; publicar **webhooks**.
* Backoffice (AdminLTE): **Materiais CRUD** + **Login OIDC** + **RBAC** básico.
* Node-RED: fluxo `materials-upsert` (webhook→BFF/Kafka) com telemetria.
* Observabilidade básica (logs, métricas) e **CI** (lint/build/test).

**31–60 dias**

* Expandir catálogos: **Tipos de OS, Produtividades, Unidades**.
* Config Center por tenant/site no Strapi (+ policies).
* Backoffice: **Gestão de Equipes** e **Permissões**; tabelas com **filtros** e **export**.
* Node-RED: integrações SaaS (notificações de aprovação, e-mails), agendamentos.
* **DR/Backups**, **DLP** no ingest de textos, **FinOps** (quotas e alertas).

**61–90 dias**

* Graduar fluxos críticos para **serviços**; deixar Node-RED para integrações/ETL leve.
* Publicar **dashboards** de uso/custo e **SLOs** de flows.
* Formalizar **contratos** (Pact/AsyncAPI) entre Strapi/Node-RED/BFF.
* Hardening: **cosign** nas imagens, SBOM, **policy-as-code** completa (Manif. 16).

---

## 10) Checklists de adoção

* [ ] OIDC/SSO funcionando em AdminLTE e Strapi Admin.
* [ ] Policies multi-tenant no Strapi ativas.
* [ ] Node-RED com **webhook HMAC** + retriable HTTP + deadletter.
* [ ] Observabilidade: métricas de CRUD/flow (p95, 5xx); logs com `tenant/site`.
* [ ] CI/CD: testes, *feature flags*, promoção GitOps.
* [ ] DLP ativo para textos/imagens (conforme Manif. 15).

---

Se quiser, eu já monto um **docker-compose** inicial com Strapi + Postgres + Node-RED + AdminLTE (Vite), além de 1–2 **flows** versionados e o **schema** de Materiais pronto para import.
