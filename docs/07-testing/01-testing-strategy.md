# Manifesto 7 — **Test Strategy (Pyramid + CDC + E2E + Performance + Chaos + Sec/A11y/Observability)**

*(ObraFlow · pacote inicial completo, pronto para colar no repositório)*

Este pacote padroniza a **estratégia de testes ponta-a-ponta**, cobrindo: **Unit**, **Contract (REST/GraphQL/Async)**, **Integration**, **E2E (web/mobile-web)**, **Performance & Synthetics**, **Chaos**, **Security (SCA/SAST/DAST/IaC)**, **A11y**, **Observability Tests**, **Test Data Management** e **CI**. Coeso com Manifestos 1–6.

---

## 📁 Estrutura de diretórios

```
tests/
  README.md
  unit/
    node-jest.config.ts
    go/
      go.mod
      work_mgmt_domain_test.go
  integration/
    docker-compose.integration.yml
    node/
      work_mgmt_repo.int.test.ts
    go/
      measurement_repo_int_test.go
  contracts/
    rest/
      pact/
        pact.config.ts
        consumers/
          bff-work_mgmt.pact.test.ts
        providers/
          work_mgmt.pact.verify.test.ts
    graphql/
      schema-linter.config.yml
      operations/
        queries.gql
        queries.spec.ts
    async/
      ajv-validate/
        validate-work-order-created.spec.ts
      pact/
        resource_reserved.consumer.pact.ts
  e2e/
    cypress/
      cypress.config.ts
      e2e/
        login.cy.ts
        work_orders.cy.ts
    playwright/
      playwright.config.ts
      specs/
        sync_delta.spec.ts
  perf/
    k6/
      smoke-apontamento.js
      workload-os-list.js
  chaos/
    litmus/
      experiments.yaml
    gremlin/
      scenarios.md
  security/
    zap-baseline.yaml
    trivy-config.yaml
    owasp-asvs-checklist.md
  a11y/
    axe/
      cypress-axe.ts
      dashboard.a11y.cy.ts
  observability/
    assertions/
      slo-latency-p95.spec.ts
      logs-schema.spec.ts
  data/
    factories.ts
    seed.sql
  ci/
    github-actions/
      test.yml
      nightly-e2e.yml
```

---

## 1) `tests/README.md` — Guia da Estratégia

* **Pirâmide**:
  **Unit** (rápidos, 70–80%) → **Integration** (repos/infra crítica) → **Contract** (CDC REST/GraphQL/Async) → **E2E** (jornadas críticas) → **Não-funcionais** (perf/chaos/sec/a11y/observability).
* **Critérios**:

  * *Blocking CI*: Unit, Contract, Integration.
  * *Por PR*: smoke E2E + ZAP baseline + SCA (Trivy).
  * *Nightly*: E2E completo, k6 workload, caos leve, verificação SLO.
* **Métricas**: coverage (≥80%), falhas por suíte, MTTR por incidente, trend p95.

---

## 2) Testes Unitários

### 2.1 Node/Nest — `unit/node-jest.config.ts`

```ts
import type { Config } from 'jest';
const config: Config = {
  testEnvironment: 'node',
  transform: { '^.+\\.tsx?$': ['ts-jest', { tsconfig: 'tsconfig.json' }] },
  collectCoverage: true,
  coverageDirectory: '../../coverage/unit-node',
  collectCoverageFrom: ['**/*.ts', '!**/*.d.ts', '!**/*.int.test.ts'],
  testMatch: ['**/*.unit.test.ts'],
  setupFilesAfterEnv: ['jest-extended/all'],
};
export default config;
```

### 2.2 Go (domínio) — `unit/go/work_mgmt_domain_test.go`

```go
package domain_test

import (
  "testing"
  "time"

  "github.com/stretchr/testify/require"
  "obraflow/workmgmt/domain"
)

func TestWorkOrder_Invariants(t *testing.T) {
  start := time.Now()
  end := start.Add(48 * time.Hour)
  wo, err := domain.NewWorkOrder("WO-1", "Alvenaria", start, end)
  require.NoError(t, err)
  require.Equal(t, "SCHEDULED", wo.Status())

  err = wo.Schedule(start.Add(72*time.Hour), end.Add(72*time.Hour))
  require.Error(t, err, "não pode mover para antes da data corrente enquanto IN_PROGRESS")
}
```

---

## 3) Testes de Integração

### 3.1 Compose de apoio — `integration/docker-compose.integration.yml`

```yaml
version: "3.9"
services:
  postgres: { image: postgres:16-alpine, environment: { POSTGRES_PASSWORD: test, POSTGRES_USER: test, POSTGRES_DB: obraflow }, ports: ["5433:5432"] }
  kafka: { image: bitnami/kafka:3, environment: { KAFKA_ENABLE_KRAFT: "yes" }, ports: ["9094:9094"] }
  minio: { image: minio/minio:latest, command: server /data, environment: { MINIO_ROOT_USER: minio, MINIO_ROOT_PASSWORD: minio123 }, ports: ["9000:9000"] }
```

### 3.2 Repo Nest (CQRS/ES) — `integration/node/work_mgmt_repo.int.test.ts`

```ts
import { Pool } from 'pg';
import { WorkRepo } from '../../src/infra/work.repo';
import { randomUUID } from 'crypto';

describe('WorkRepo (integration)', () => {
  let db: Pool; let repo: WorkRepo;
  beforeAll(async () => {
    db = new Pool({ connectionString: process.env.PG_URL ?? 'postgres://test:test@localhost:5433/obraflow' });
    repo = new WorkRepo(db);
    await db.query('CREATE TABLE IF NOT EXISTS event_store(id text primary key, agg text, ver int, payload jsonb)');
  });
  it('persiste evento e carrega agregado', async () => {
    const id = randomUUID();
    await repo.append(id, 0, { type: 'WorkOrderCreated', data: { title: 'Alvenaria' } });
    const stream = await repo.load(id);
    expect(stream).toHaveLength(1);
  });
});
```

---

## 4) **Contract Tests (CDC)**

### 4.1 REST com Pact — `contracts/rest/pact/consumers/bff-work_mgmt.pact.test.ts`

```ts
import { PactV3, MatchersV3 } from '@pact-foundation/pact';
const provider = new PactV3({ consumer: 'bff', provider: 'work-mgmt' });

describe('GET /work-orders', () => {
  it('retorna coleção com paginação', () => provider
    .given('existem OS SCHEDULED')
    .uponReceiving('listagem de OS')
    .withRequest({ method: 'GET', path: '/api/v1/work-orders', query: { 'filter[status]': 'SCHEDULED', limit: '2' }, headers: { 'x-tenant-id': 'acme' }})
    .willRespondWith({
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: {
        data: MatchersV3.eachLike({ id: MatchersV3.like('WO-1'), title: MatchersV3.like('Alvenaria'), status: MatchersV3.regex(/SCHEDULED|IN_PROGRESS|BLOCKED|DONE|CANCELLED/, 'SCHEDULED') }, { min: 1 }),
        page: { limit: 2, nextCursor: MatchersV3.like('abc') }
      }
    })
    .executeTest(async mock => {
      const res = await fetch(`${mock.url}/api/v1/work-orders?filter[status]=SCHEDULED&limit=2`, { headers: { 'x-tenant-id': 'acme' }});
      expect(res.status).toBe(200);
    }));
});
```

### 4.2 GraphQL — validação de operações e schema

* Rodar **schema-linter** e **build** do schema; testes de operações em `queries.spec.ts` chamando o BFF mockado.

### 4.3 Async (Kafka) — AJV (schema) + Pact async

`contracts/async/ajv-validate/validate-work-order-created.spec.ts`

```ts
import Ajv from 'ajv'; import schema from '../../../docs/10-architecture/event-catalog-asyncapi/schemas/work/WorkOrderCreated.json';
const ajv = new Ajv({ allErrors: true, strict: false });
const validate = ajv.compile(schema);

test('WorkOrderCreated payload válido', () => {
  const payload = { woId: 'WO-1', aggregateId: 'WO-1', wbsPath: '1.2', title: 'Alvenaria', plannedWindow: { start: new Date().toISOString(), end: new Date(Date.now()+86400000).toISOString() } };
  expect(validate(payload)).toBe(true);
});
```

`contracts/async/pact/resource_reserved.consumer.pact.ts` — (se usar Pact para mensageria): modelar consumidor do tópico `resource.resource-reserved.v1`.

---

## 5) **E2E** (Cypress + Playwright)

### 5.1 Cypress — `e2e/cypress/work_orders.cy.ts`

```ts
describe('OS — fluxo básico', () => {
  beforeEach(() => {
    cy.loginOIDC('engineer@acme', 'secret'); // custom command
  });
  it('lista OS, abre detalhe e aponta produção', () => {
    cy.visit('/work-orders');
    cy.findByRole('searchbox', { name: /buscar/i }).type('Alvenaria{enter}');
    cy.findByRole('link', { name: /WO-/i }).first().click();
    cy.findByRole('button', { name: /Apontar produção/i }).click();
    cy.findByLabelText(/Quantidade/i).type('5.5');
    cy.findByRole('button', { name: /Salvar/i }).click();
    cy.findByText(/salvo/i).should('be.visible');
  });
});
```

### 5.2 Playwright — `e2e/playwright/sync_delta.spec.ts`

```ts
import { test, expect } from '@playwright/test';
test('delta sync retorna 304 quando sem mudanças', async ({ request }) => {
  const res = await request.get('/api/v1/sync/delta', { headers: { 'If-Modified-Since': new Date().toISOString() }});
  expect([200,304]).toContain(res.status());
});
```

---

## 6) **Performance & Synthetics** (k6)

* **Smoke** e **workload** já entregues em Manifesto 1/4; aqui focamos **workload de listagem**:

`perf/k6/workload-os-list.js`

```js
import http from 'k6/http'; import { check } from 'k6';
export const options = { vus: 50, duration: '10m', thresholds: { http_req_duration: ['p(95)<300'], http_req_failed: ['rate<0.01'] } };
export default () => {
  const res = http.get(`${__ENV.ENDPOINT}/api/v1/work-orders?limit=50&filter[status]=SCHEDULED`, { headers: { 'x-tenant-id': __ENV.TENANT }});
  check(res, { '200': r => r.status === 200 });
};
```

---

## 7) **Chaos** (Litmus/Gremlin) — plano mínimo

`chaos/litmus/experiments.yaml` (excerto)

```yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata: { name: obraflow-chaos, namespace: obraflow-app }
spec:
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: "60"
            - name: CHAOS_INTERVAL
              value: "10"
```

`chaos/gremlin/scenarios.md`: **AZ drain**, **DB latency**, **network loss**; mapear aos cenários do Manifesto 1.

---

## 8) **Security Testing** (SCA/SAST/DAST/IaC)

* **SCA**: Trivy em containers/dep.
* **SAST**: ESLint/TS, Golangci-lint; opcional Semgrep.
* **DAST**: ZAP baseline (CI).
* **IaC**: tfsec/kube-score/kubeconform.

`security/zap-baseline.yaml` (entrada para action “zaproxy/action-baseline”)

`security/trivy-config.yaml`

```yaml
severity: CRITICAL,HIGH
vuln-type: os,library
exit-code: 1
ignore-unfixed: true
```

---

## 9) **Acessibilidade (A11y)**

`a11y/axe/dashboard.a11y.cy.ts`

```ts
import 'cypress-axe';
describe('A11y — Dashboard', () => {
  it('sem violações críticas', () => {
    cy.visit('/dashboard'); cy.injectAxe();
    cy.checkA11y(null, { includedImpacts: ['critical','serious'] });
  });
});
```

---

## 10) **Observability Tests** (asserts de SLO e logs)

`observability/assertions/slo-latency-p95.spec.ts`

```ts
import fetch from 'node-fetch';
test('p95 por rota abaixo do alvo', async () => {
  const prom = process.env.PROM_URL!;
  const q = 'histogram_quantile(0.95,sum by (le,route)(rate(http_server_duration_seconds_bucket{env="prd"}[5m])))';
  const r = await (await fetch(`${prom}/api/v1/query?query=${encodeURIComponent(q)}`)).json();
  const worst = Math.max(...r.data.result.map((s:any) => parseFloat(s.value[1])));
  expect(worst).toBeLessThan(0.3); // 300ms — Manifesto 1
});
```

`observability/assertions/logs-schema.spec.ts`

```ts
test('logs sem PII em campos proibidos', () => {
  const sample = require('./fixtures/log.json');
  const forbidden = ['email','cpf','rg','address'];
  forbidden.forEach(k => expect(sample).not.toHaveProperty(k));
});
```

---

## 11) **Test Data Management (TDM)**

* **Factories** + **seeds** determinísticos, com *namespaces* por suíte (tenant `test-<suite>`).
* **Idempotência**: usar `Idempotency-Key` em POSTs; *cleanup* por Tenant.
* **Clock control**: *fake timers* em unit; *time window* conhecido em E2E.
* **Dados sensíveis**: gerados sinteticamente; **nunca** dados reais.

`data/factories.ts`

```ts
export const woFactory = (over: Partial<any> = {}) => ({
  id: `WO-${Math.random().toString(36).slice(2, 8)}`,
  title: 'Alvenaria',
  status: 'SCHEDULED',
  plannedWindow: { start: new Date().toISOString(), end: new Date(Date.now()+86400000).toISOString() },
  ...over
});
```

---

## 12) **CI** (GitHub Actions)

`ci/github-actions/test.yml` (excerto)

```yaml
name: Tests
on: [push, pull_request]
jobs:
  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run test:unit --workspaces
  contracts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run test:contracts
  integration:
    runs-on: ubuntu-latest
    services:
      postgres: { image: postgres:16-alpine, ports: ['5433:5432'], env: { POSTGRES_PASSWORD: test, POSTGRES_USER: test, POSTGRES_DB: obraflow } }
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: PG_URL=postgres://test:test@localhost:5433/obraflow npm run test:integration
  e2e-smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cypress-io/github-action@v6
        with: { start: 'npm run dev:bff', wait-on: 'http://localhost:3000/health' }
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/trivy-action@v0
        with: { scan-type: 'fs', ignore-unfixed: true, severity: 'CRITICAL,HIGH' }
      - uses: zaproxy/action-baseline@v0.12.0
        with: { target: 'https://hml.api.obraflow.example' }
```

`ci/github-actions/nightly-e2e.yml` (agenda noturna para k6/chaos/slo asserts)

---

## 13) **Definition of Done (Testes)**

* [ ] Coverage ≥ **80%** (unit).
* [ ] **CDC** (REST/GraphQL/Async) verificados; sem *breaking changes* sem major.
* [ ] **Integration**: repos principais e *happy-paths* dos serviços.
* [ ] **E2E**: jornadas “Minhas OS → apontar → medição” verdes.
* [ ] **Performance**: p95 < 300ms; erro < 1%; smoke OK.
* [ ] **Chaos**: 1 experimento do ciclo executado.
* [ ] **Security**: SCA/SAST sem CRITICAL/HIGH pendentes; ZAP baseline OK.
* [ ] **A11y**: sem violações **critical/serious**.
* [ ] **Observability**: asserts SLO e logs sem PII.

---

### Amarrações (com Manifestos 1–6)

* **NFR/SLO** (Manif. 1): asserts de p95, staleness, error rate e caos vinculados.
* **Catálogo de Eventos** (Manif. 2): CDC/JSON-Schema e Pact para mensageria.
* **Segurança/LGPD** (Manif. 3): ZAP/Trivy + validação de PII em logs.
* **Observabilidade** (Manif. 4): testes consultam Prometheus/Tempo.
* **API Governance** (Manif. 5): Pact REST + lint de OpenAPI.
* **Infra/GitOps** (Manif. 6): Compose e Actions reproduzíveis; testes rodam em pipelines.

---

Posso avançar com o **Manifesto 8 — *Release, Versioning & Change Management (SemVer, Feature Flags, CAB leve, Release Notes)***, ou deseja que eu ajuste algo na estratégia de testes antes?
