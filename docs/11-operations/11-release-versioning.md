# Manifesto 8 — **Release, Versioning & Change Management**

*(SemVer, Branching, CI/CD, Feature Flags, Notas de Release, Migrações, Promoção entre Ambientes, Congelamentos por SLO)*

Este manifesto de operações foi **integrado com os padrões técnicos** definidos no plano de ação do monorepo, garantindo alinhamento entre arquitetura, desenvolvimento e operações. Estabelece **releases previsíveis**, **compatibilidade**, **rollouts seguros** e **rastreabilidade** ponta-a-ponta.

## 🚀 Integração com Padrões de Operações do Monorepo

### Stack de Operações Integrada
- **Versionamento**: SemVer com conventional commits e semantic-release
- **CI/CD**: GitHub Actions com Nx + pnpm + Changesets
- **Feature Flags**: OpenFeature com providers configuráveis
- **GitOps**: ArgoCD com promoção entre ambientes
- **Observabilidade**: SLOs como gates de release

### Padrões de Operações Aplicados
- **TypeScript**: Changesets para versionamento independente
- **Go**: Versionamento via tags e releases automáticos
- **Cross-cutting**: Conventional commits, feature flags, SLO gates

---

## 📁 Estrutura de arquivos

```
release/
  README.md
  policy.md
  branching.md
  semver.md
  mobile-versioning.md
  feature-flags/
    openfeature-guidelines.md
    flags.schema.json
    flags.sample.json
    sdk/
      node-openfeature.ts
      go-openfeature.go
  migrations/
    expand-contract.md
    db-migrate-template.sql
    data-backfill-playbook.md
  automation/
    semantic-release.config.cjs
    release-notes.hbs
    conventional-commits.md
    gh-actions/
      release.yml
      promote-hml-to-prd.yml
      release-freeze-by-slo.yml
  rollout/
    strategies.md
    canary-checklist.md
    bluegreen-checklist.md
    post-release-verification.md
  change-advisory/
    lightweight-cab.md
    risk-matrix.md
  hotfix/
    hotfix-process.md
```

---

## 1) `release/README.md` — Guia rápido

```markdown
# Releases — ObraFlow

- **Trunk-based**: `main` é integrado continuamente; *feature flags* para inacabados.
- **SemVer**: versão do **produto** e versões de **contratos** (REST/GraphQL/Eventos) coordenadas.
- **Automação**: `semantic-release` gera tag, changelog e notas → cria GitHub Release.
- **Promoção**: dev → hml → prd via **ArgoCD** (app-of-apps).
- **Congelamento**: pipeline bloqueia release se **SLO** em burn (> thresholds).

> *TL;DR:* Faça *conventional commit*, abra PR com testes verdes, `main` mergeado → **release automático** em dev; promoção para hml/prd sob critérios.
```

---

## 2) `policy.md` — Política de Release

```markdown
# Política de Release

- **Cadência**:
  - `dev`: contínua (todas as merges em `main`).
  - `hml`: diária (janela 11:00–13:00 BRT), via workflow de promoção.
  - `prd`: 2–3x/semana (janela 08:00–10:00 BRT).

- **Qualidade mínima**:
  - Testes: unit+integration+CDC **verdes**, E2E smoke OK (Manifesto 7).
  - SLOs últimos 7d: latência p95 ≤ alvo; erro 5xx ≤ 1%; **sem** DLQ > 0.1% (Manif. 1/4).
  - Segurança: SCA/SAST sem **CRITICAL/HIGH** abertos; ZAP baseline OK (Manif. 7).

- **Congelamentos**:
  - **Freeze automático** por erro orçamentário (error budget) (Manif. 1): burn *fast* > 5%/h ou *slow* > 1%/6h → pausa promoção a prd.
  - **Holiday freeze** programado via calendário (arquivo `.freeze`).

- **Aprovação**:
  - hml: aprovação do time dono do épico.
  - prd: *lightweight CAB* (duas aprovações: Engenheiro responsável + PO).

- **Rollback**:
  - Deploys versionados e imutáveis; **revert** Helm/ArgoCD; *DB expand-contract* (sem *down* perigoso).
```

---

## 3) `branching.md` — Branching e PR

```markdown
# Branching

- `main`: protegido; merge via PR + checks.
- *Short-lived branches*: `feat/<épico>`, `fix/<issue>`, `chore/<tarefa>`.
- Sem *release branches* longas; *feature flags* protegem código incompleto.
- **PR checklist**: testes, lint, contrato (OpenAPI/AsyncAPI), migração *expand* pronta, *observability hooks*.
```

---

## 4) `semver.md` — Versão do Produto & Contratos

```markdown
# SemVer

- **Produto (monorepo)**: `major.minor.patch` tag em `main` (ex.: `v1.4.2`).
- **REST/GraphQL**: *path versioning* (`/api/v1`), *deprecations* documentadas; *breaking* → `v2`.
- **Eventos Kafka**: tópico com sufixo `.v1` (Manif. 2); *breaking* → novo tópico `.v2`.
- **Mobile**: semântica + *build number* separado (ver `mobile-versioning.md`).
```

---

## 5) `mobile-versioning.md` — App Stores & Compatibilidade

```markdown
# Versão Mobile

- **Versão**: `major.minor.patch (build)` (ex.: 1.7.0 (10700)).
- **Compatibilidade de API**: app `N` deve operar com API de `N-1` até `N+1` (janela suporte).
- **Kill Switch** remoto (feature flag): bloqueia versões inseguras/obsoletas.
- **Rollout** progressivo nas stores (staged rollout 5% → 25% → 100%).
```

---

## 6) `feature-flags/openfeature-guidelines.md` — Flags e *Guards*

```markdown
# Feature Flags (OpenFeature)

- **Tipos**: *release*, *ops*, *experiments*, *permissions*.
- **Escopo**: por tenant/obra/role (ABAC).
- **Boas práticas**:
  - Toda flag deve ter *owner*, *sunset date* e *guardrails* (SLO/segurança).
  - **Kill switch** para operações de risco (alocação em massa).
  - Remoção de flags antigas ≤ 30 dias após GA.
```

`flags.schema.json` (validação)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Flags",
  "type": "object",
  "patternProperties": {
    "^[a-z][a-z0-9_.-]{2,}$": {
      "type": "object",
      "required": ["type","default","owner","sunsetAt"],
      "properties": {
        "type": { "enum": ["release","ops","experiment","permission"] },
        "default": { "type": ["boolean","number","string","object"] },
        "rules": { "type": "array", "items": { "type": "object" } },
        "owner": { "type": "string" },
        "sunsetAt": { "type": "string", "format": "date" },
        "description": { "type": "string" }
      }
    }
  },
  "additionalProperties": false
}
```

`flags.sample.json`

```json
{
  "work.alloc.ai_suggestions": {
    "type": "release",
    "default": false,
    "rules": [
      { "when": { "tenant": "acme" }, "then": true }
    ],
    "owner": "work-allocation-team",
    "sunsetAt": "2026-03-31",
    "description": "Sugestões de alocação assistida por IA"
  },
  "ops.kill.mobile_v<1.5": {
    "type": "ops",
    "default": false,
    "owner": "platform",
    "sunsetAt": "2025-12-31",
    "description": "Desativa clientes antigos com riscos"
  }
}
```

SDK Node (OpenFeature) — `feature-flags/sdk/node-openfeature.ts`

```ts
import { OpenFeature, Client } from '@openfeature/js-sdk';

export async function flagsClient(context: { tenant: string; site?: string; role?: string }): Promise<Client> {
  // provider configurado em bootstrap (e.g., Flagd, Unleash, ConfigCat)
  const client = OpenFeature.getClient('obraflow');
  OpenFeature.setContext(context);
  return client;
}

// Uso
// const client = await flagsClient({ tenant: 'acme', role: 'engineer' });
// const enabled = await client.getBooleanValue('work.alloc.ai_suggestions', false);
```

SDK Go — `feature-flags/sdk/go-openfeature.go`

```go
package flags
import (
  of "github.com/open-feature/go-sdk/openfeature"
)
func Client(ctx map[string]any) of.Client {
  c := of.NewClient("obraflow")
  of.SetContext(ctx)
  return c
}
```

---

## 7) Migrações de Banco — `migrations/expand-contract.md`

````markdown
# Expand/Contract

- **Fase 1 (Expand)**: adicionar colunas/tabelas compatíveis; código escreve em **ambos** (dual-write) se necessário.
- **Fase 2 (Migrate/Backfill)**: backfill assíncrono com *idempotência* e *checkpoints*.
- **Fase 3 (Cutover)**: alternar leitura para novo esquema; manter dados atualizados.
- **Fase 4 (Contract)**: remover legado **após** período de observação (≥ 2 releases).
- **Proibições**: renomear coluna no lugar; *locks* de tabela longos; migrações que exigem downtime.

`db-migrate-template.sql`
```sql
-- expand: adicionar coluna nullable + índice simultâneo
ALTER TABLE work_orders ADD COLUMN IF NOT EXISTS wbs_path text NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_work_orders_wbs ON work_orders (wbs_path);
-- contract (posterior, outra PR): DROP INDEX ... ; ALTER COLUMN wbs_path SET NOT NULL;
````

`data-backfill-playbook.md` — orquestração via job com *batches*, *retries* e métricas.

````

---

## 8) Automação — `semantic-release`

`automation/semantic-release.config.cjs`
```js
module.exports = {
  branches: ['main'],
  repositoryUrl: 'https://github.com/sua-org/obraflow',
  plugins: [
    '@semantic-release/commit-analyzer',         // convencional commits → tipo de versão
    ['@semantic-release/release-notes-generator',{preset: 'conventionalcommits'}],
    ['@semantic-release/changelog', { changelogFile: 'CHANGELOG.md' }],
    ['@semantic-release/git', { assets: ['CHANGELOG.md'] }],
    ['@semantic-release/github', { assets: [] }]
  ]
};
````

`automation/release-notes.hbs` (template Handlebars — trechos)

```hbs
# {{nextRelease.version}} ({{datetime "YYYY-MM-DD"}})

{{#if commits}}
## Mudanças
{{#each commits}}
- {{this.subject}}
{{/each}}
{{/if}}

## Quebra de compatibilidade
{{#each releases}}
{{#each commits}}
{{#if this.notes.breaking}}
- {{this.notes.breaking}}
{{/if}}
{{/each}}
{{/each}}

_Artefatos, migrações e *feature flags* associadas por épico._
```

`automation/conventional-commits.md` — guia (feat/fix/perf/refactor/docs/test/chore/ci) + escopos por serviço.

`automation/gh-actions/release.yml`

```yaml
name: semantic-release
on:
  push:
    branches: [main]
jobs:
  release:
    runs-on: ubuntu-latest
    permissions: { contents: write, issues: write, pull-requests: write }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npx semantic-release
```

---

## 9) Promoção entre ambientes (GitOps)

`automation/gh-actions/promote-hml-to-prd.yml`

```yaml
name: Promote HML → PRD
on:
  workflow_dispatch:
    inputs:
      version: { description: 'Tag (ex.: v1.4.2)', required: true }
jobs:
  promote:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Bump Helm values (image tag)
        run: |
          sed -i "s/tag: \".*\"/tag: \"${{ github.event.inputs.version }}\"/g" infra/charts/obraflow-service/values.yaml
      - name: Commit & PR
        run: |
          git config user.name "release-bot"; git config user.email "release@bot"
          git checkout -b promote/${{ github.event.inputs.version }}
          git commit -am "ci: promote ${{ github.event.inputs.version }} to prd"
          git push -u origin promote/${{ github.event.inputs.version }}
      - name: Open PR
        uses: peter-evans/create-pull-request@v6
        with: { title: "Promote ${{ github.event.inputs.version }} to prd", branch: "promote/${{ github.event.inputs.version }}" }
```

---

## 10) Congelamento por SLO — **freeze automático**

`automation/gh-actions/release-freeze-by-slo.yml`

```yaml
name: Release Freeze by SLO
on:
  schedule: [{ cron: "*/30 * * * *" }]
jobs:
  check-slo:
    runs-on: ubuntu-latest
    steps:
      - name: Query Prometheus burn rate
        run: |
          PROM=${{ secrets.PROM_URL }}
          FAST=$(curl -s "$PROM/api/v1/query?query=rate(api_errors[1h])/rate(api_requests[1h])")
          if [[ $(echo "$FAST" | jq '.data.result[0].value[1] | tonumber > 0.05') == "true" ]]; then
            echo "Freeze ON"
            echo "frozen=true" >> $GITHUB_OUTPUT
          fi
      - name: Create/Update Freeze Issue
        if: steps.check-slo.outputs.frozen == 'true'
        uses: peter-evans/create-issue-from-file@v5
        with:
          title: "🚫 Release frozen by SLO (fast burn)"
          content-filepath: release/.freeze
```

`release/.freeze` — marcador de congelamento (monitorado por *branch protection rule* ou job que impede `promote-hml-to-prd`).

---

## 11) Estratégias de Rollout — `rollout/strategies.md`

```markdown
# Estratégias

- **Canary** (recomendado): 1% → 5% → 25% → 100% com *SLO guards* (p95, 5xx, DLQ).
- **Blue/Green**: troca de *gateway route* após verificação de saúde/sintéticos.
- **Progressive Delivery**: Argo Rollouts (opcional) com *analysis templates* (Prom/OTel).

`canary-checklist.md`:
- [ ] Métricas alvo definidas (p95/5xx/lag).
- [ ] *Feature flags* default OFF (gradual por tenant/obra).
- [ ] Sondas sintéticas ativas.
- [ ] Playbook de rollback validado.

`bluegreen-checklist.md`:
- [ ] Tráfego espelhado (shadow) OK.
- [ ] Banco em modo expand (sem *contract*).
- [ ] Switch de rota e *post-release verification*.

`post-release-verification.md`:
- [ ] Painel RED verde; sem alertas críticos.
- [ ] Eventual consistência (outbox/lag) dentro da banda.
- [ ] Aumento de erros nos endpoints alterados? Se sim → *kill switch*.
```

---

## 12) Change Advisory (leve) — `change-advisory/lightweight-cab.md`

```markdown
# Lightweight CAB

- **Quem**: Engineer (owner), PO, SRE (assíncrono via PR/issue template).
- **Quando**: mudanças com risco `M` ou `A` (ver `risk-matrix.md`).
- **Como**: PR marcado `change:review`, checklist de risco, janela, plano de rollback, flags.
- **SLA**: 4h úteis.
```

`risk-matrix.md` — probabilidade × impacto, define quando CAB é obrigatório.

---

## 13) Hotfix — `hotfix/hotfix-process.md`

```markdown
# Hotfix

- Crie branch `hotfix/<id>`, commit `fix:`; bypass parcial de cadência (apenas prd).
- **Critérios**: regressão severa, falha de segurança alta/critical, violação de SLO.
- **Fluxo**: PR → testes críticos → deploy direto para prd (canary 10%) → backport para `main`.
- **Observabilidade**: monitorar p95/5xx por 30 min; RCA em 48h.
```

---

## 14) Amarrações (com os Manifestos anteriores)

* **Manif. 1 (NFR/SLO)**: *freeze* por burn rate; verificação de SLO no *gating*.
* **Manif. 2 (Eventos)**: versionamento `.vN`, DLQ monitorada em rollout.
* **Manif. 3 (Segurança/LGPD)**: *kill switch* de versões vulneráveis, CAB registra DPIA quando necessário.
* **Manif. 4 (Observabilidade)**: painéis RED/USE e *post-release verification*.
* **Manif. 5 (API Gov)**: SemVer de contratos, depreciações documentadas.
* **Manif. 6 (Infra/GitOps)**: promoção via ArgoCD, blue/green/canary.
* **Manif. 7 (Tests)**: gates de testes, sintéticos e asserts SLO.

## 🔄 Integração com Padrões do Monorepo

### Estrutura de Operações Aplicada
```
obraflow/
├── .changeset/                     # Versionamento independente TS
├── .github/workflows/
│   ├── release.yml                 # Semantic release
│   ├── promote-hml-to-prd.yml     # Promoção entre ambientes
│   └── release-freeze-by-slo.yml  # Congelamento por SLO
├── release/
│   ├── feature-flags/              # OpenFeature configs
│   ├── migrations/                 # DB migration templates
│   └── rollout/                    # Estratégias de rollout
└── tools/scripts/release/          # Scripts de release
```

### Padrões de Operações por Linguagem
- **TypeScript**: Changesets para versionamento independente, semantic-release
- **Go**: Versionamento via tags, releases automáticos via GitHub Actions
- **Cross-cutting**: Conventional commits, feature flags, SLO gates

### Critérios de Aceite de Operações
- **Releases automáticos** via conventional commits
- **Feature flags** funcionando em todos os ambientes
- **SLOs** como gates de release
- **Promoção entre ambientes** via GitOps

---

Se estiver de acordo, sigo para o **Manifesto 9 — *Runbooks & Incident Management (RACI, Severidades, RCA, Comms)*** ou prefere ajustar algum ponto deste manifesto (ex.: cadência, freeze window, flags provider, canary guardrails)?
