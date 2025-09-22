Plano de Ação (por etapas) — Monorepo Multilíngue TS (Next, Expo, Nest, Libs) e Go (Echo, Fx, Watermill) com aceleração por Agentes de IA

> Objetivo: estabelecer um monorepo padronizado, escalável e observável, com fluxos de CI/CD, versionamento independente de libs/apps, e um “banco de prompts operacionais” para acelerar a codificação com agentes especializados (frontend, mobile, BFF, backend Go, observabilidade, segurança, dados, DevOps e release).




---

1) Diretrizes Gerais de Arquitetura

Estratégia de Monorepo

TypeScript: Nx + pnpm (workspaces) como orquestrador (Next/Expo/Nest/libs), Biome para lint/format, Jest/Vitest para testes.

Go: go work (multi-módulo), padronização com Taskfile/Makefile e integração a Nx via run-commands (evita dependência de plugin de terceiros).

Fronteiras de Domínio (DDD): libs core (contratos, eventos, Result/Either, erros, logging, tracing) → reuso entre apps TS; em Go, pkg/ (shared) e internal/ (por serviço).

Cross-cutting: logging estruturado (Pino em TS, Zap em Go), OTel (traces/metrics), correlação (trace-id, span-id), policies (retries, circuit breaker), segurança (JWT, RBAC, validação).

CQRS+EDA: Nest (TS) e Watermill (Go) para mensageria/eventos; HTTP REST/GraphQL expostos por BFF (Nest).


Versionamento/Release

TS: Changesets com versionamento independente por pacote; publicação em registry privado (GitHub Packages/Nexus).

Go: versão por tag SemVer por módulo; binários com Goreleaser; imagens com Buildx.


Qualidade/Segurança

SAST (CodeQL/Semgrep), SBOM (Syft), image scanning (Trivy), dependency review (Dependabot + pnpm audit + govulncheck).


Observabilidade

OTel SDK (TS/Go) → OTel Collector → Tempo/Jaeger (traces), Prometheus/Mimir (métricas), Loki (logs), Grafana (dashboards & alerting).


CI/CD

GitHub Actions (matriz TS/Go) com caching (pnpm store, Go build cache), pipelines por path filters, previews (Vercel/Expo EAS/Docker).




---

2) Estrutura de Diretórios Recomendada

repo/
├─ apps/
│  ├─ web-next/                  # Next.js (App Router)
│  ├─ mobile-expo/               # Expo (managed)
│  ├─ bff-nest/                  # Nest (API Gateway/BFF)
│  └─ svc-accounts-go/           # Go Echo + Fx + Watermill
├─ libs/
│  ├─ ts/
│  │  ├─ framework-core/         # Result<E,T>, erros, eventos, ports
│  │  ├─ logging-pino/
│  │  ├─ otel-sdk/
│  │  ├─ security/               # RBAC, JWT, policies
│  │  └─ http-client/            # fetch/axios c/ retry & tracing
│  └─ go/
│     ├─ pkg/
│     │  ├─ logging/             # zap wrappers
│     │  ├─ otel/                # OTel setup
│     │  └─ events/              # contracts p/ Watermill
│     └─ internal/               # utilitários internos compartilháveis
├─ tools/
│  ├─ generators/                # Nx generators (scaffolds padronizados TS)
│  └─ scripts/                   # scripts de automação (lint, release)
├─ .changeset/                   # changesets (TS)
├─ .github/workflows/            # pipelines
├─ Taskfile.yml                  # tasks (Go/gerais)
├─ go.work                       # multi-módulo Go
├─ package.json                  # pnpm workspaces
├─ nx.json                       # Nx config
├─ pnpm-workspace.yaml
├─ biome.json                    # lint/format TS
└─ CODEOWNERS


---

3) Etapas do Plano (com entregáveis e critérios de aceite)

Etapa 0 — Foundations & Policies

Objetivo: preparar políticas globais.

Tarefas:

Definir Conventional Commits, branching (trunk + feature branches curtas), CODEOWNERS, PR template, review rules.

Ativar branch protection (status checks, reviews).

Criar ADR-0001 (arquitetura monorepo), RFC-0001 (padrões observabilidade).


Entregáveis: CONTRIBUTING.md, CODEOWNERS, SECURITY.md, ADR/RFC no docs/.

Aceite: PR obrigatório + Action “policy-checks” verde (linters/licenças).



---

Etapa 1 — Bootstrap do Monorepo

Objetivo: workspace Nx (TS) + go.work (Go), pnpm, Biome.

Tarefas:

Inicializar pnpm, Nx, Biome; configurar nx.json e targets genéricos.

Criar go.work e módulos Go (root + apps/svc-accounts-go + libs/go/...).

Taskfile com alvos globais (task lint, task test, task build).


Exemplos:

go.work:

go 1.22

use ./apps/svc-accounts-go
use ./libs/go

Taskfile.yml (trecho):

version: '3'
tasks:
  lint: go vet ./... && golangci-lint run
  test: go test ./... -coverprofile=coverage.out
  build: go build ./...
  ts:fmt: pnpm biome check --write .
  ts:lint: pnpm biome check .
  ts:test: pnpm nx run-many -t test


Aceite: pnpm install e task build funcionam; nx graph abre o grafo.



---

Etapa 2 — Libs TS base (framework-core, logging, otel, security)

Objetivo: padronizar contratos e infra de cross-cutting para TS.

Tarefas:

libs/ts/framework-core: Result<T,E>, DomainError, Event, Command, Query, UseCase.

libs/ts/logging-pino: logger Pino com redaction/traceId.

libs/ts/otel-sdk: inicialização OTel (Node/Browser), auto-instrumentation.

libs/ts/security: JWT, RBAC, decorators (Nest), guards.


Aceite: libs testáveis (Jest/Vitest) e reutilizáveis sem dependência circular.



---

Etapa 3 — Libs Go base (logging, otel, events)

Objetivo: building blocks Go reutilizáveis.

Tarefas:

libs/go/pkg/logging: zap.Logger inicializado com níveis, campos padrão (traceId).

libs/go/pkg/otel: tracer/meter/propagators; helper p/ HTTP (Echo) e Watermill.

libs/go/pkg/events: contratos e helpers p/ mensagens (keying/headers).


Aceite: go test ./libs/go/... com cobertura mínima acordada.



---

Etapa 4 — Apps iniciais

Objetivo: compilar o esqueleto funcional dos apps.

Next.js (apps/web-next): App Router, auth stub, rota observável (middleware com trace).

Expo (apps/mobile-expo): navegação, fetch client com tracing.

Nest BFF (apps/bff-nest): módulos Core (logging/otel/security), endpoints health, metrics, whoami.

Go Echo + Fx + Watermill (apps/svc-accounts-go):

Fx organiza módulos: fx.Provide(logger, config, db opcional, watermill router), fx.Invoke(start HTTP, subscrições).

Echo servidores HTTP; Watermill pub/sub (ex.: Kafka/NATS ou in-memory no dev).


Aceite: nx run-many -t build e task build passam; docker compose up sobe stack local.


> Exemplo mínimo Go (main):



// apps/svc-accounts-go/cmd/main.go
package main

import (
  "context"
  "net/http"
  "os"
  "os/signal"
  "syscall"
  "time"

  "go.uber.org/fx"
  "github.com/labstack/echo/v4"

  // libs locais
  "repo/libs/go/pkg/logging"
  "repo/libs/go/pkg/otel"
)

func main() {
  fx.New(
    fx.Provide(
      logging.NewLogger,      // *zap.Logger
      otel.NewProvider,       // TracerProvider/MeterProvider + shutdown
      newEcho,                // *echo.Echo
    ),
    fx.Invoke(runHTTP),
  ).Run()
}

func newEcho() *echo.Echo {
  e := echo.New()
  e.GET("/health", func(c echo.Context) error {
    return c.String(http.StatusOK, "ok")
  })
  return e
}

func runHTTP(lc fx.Lifecycle, e *echo.Echo) {
  srv := &http.Server{Addr: ":8080", Handler: e}
  lc.Append(fx.Hook{
    OnStart: func(ctx context.Context) error {
      go srv.ListenAndServe()
      return nil
    },
    OnStop: func(ctx context.Context) error {
      shutdownCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
      defer cancel()
      return srv.Shutdown(shutdownCtx)
    },
  })

  // graceful shutdown (opcional fora do Fx)
  go func() {
    sig := make(chan os.Signal, 1)
    signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
    <-sig
    _ = srv.Shutdown(context.Background())
  }()
}


---

Etapa 5 — Observabilidade integrada

Objetivo: instrumentar TS e Go com OTel e padronizar pipelines.

Tarefas:

TS (Nest/Next/Expo): inicializar tracer (auto-instrumentation http/fetch/express), pino com bindings de traceId.

Go: Echo middleware p/ trace; Watermill middlewares de correlação; export OTLP.

Subir otel-collector, Grafana, Tempo/Jaeger, Loki, Prometheus via docker compose no dev.


Aceite: traços de requisições web→bff→svc-accounts-go visíveis em Jaeger/Tempo; métricas básicas expostas.



---

Etapa 6 — CI/CD e Qualidade

Objetivo: pipelines padronizadas.

Tarefas:

Workflow build-and-test (matriz TS/Go); path filters por pasta.

SonarQube (quando aplicável TS), golangci-lint, govulncheck, SBOM (Syft), Trivy nas imagens.

Previews: Vercel (Next), Expo EAS, Docker registry (GHCR) para Go/Nest.


Aceite: PRs exigem green checks; caching reduz tempo de build.



---

Etapa 7 — Versionamento & Release

Objetivo: releases automatizados por componente.

Tarefas:

TS: Changesets com independent versioning, changeset version + changeset publish; changelog por pacote.

Go: goreleaser + tags SemVer por módulo; binaries e imagens multi-arch.


Aceite: criar uma release de exemplo para libs/ts/framework-core e apps/svc-accounts-go.



---

Etapa 8 — Segurança & Compliance

Objetivo: linha de base de segurança.

Tarefas:

Política de segredos (SOPS/Sealed Secrets), verificação de chaves, varredura de segredos (Gitleaks).

Threat model inicial (docs), CSP/headers no Next/Nest/Echo.


Aceite: pipelines falham na presença de segredos ou CVEs bloqueantes.



---

Etapa 9 — DX & Automação

Objetivo: produtividade por generators e CLIs.

Tarefas:

Nx generators (TS): g app nest-svc, g lib ts-core, g feature ui.

Scaffolds Go via Task (padrões Echo+Fx+Watermill).


Aceite: criação de um serviço completo via “um comando” (TS e Go) + prompt agent (abaixo).



---

Etapa 10 — Documentação Viva

Objetivo: governança e rastreabilidade.

Tarefas:

C4 (Context/Container/Component) + ADRs/RFCs por módulo; Docs-as-code (Docusaurus/Next).


Aceite: diagrama C4 L2/L3 publicado e vinculado a cada app.



---

4) Banco de Prompts Operacionais para Agentes de IA (com exemplos)

> Formato: [Template objetivo] seguido de Exemplo preenchido (sem lacunas), pronto para “copiar e colar”.



4.1 Agente Repo Architect (Bootstrap Nx + pnpm + go.work)

Template
“Crie um bootstrap de monorepo com Nx (Next/Expo/Nest/libs TS), pnpm e Biome; inclua pnpm-workspace.yaml, nx.json, biome.json, go.work com módulos apps/svc-accounts-go e libs/go. Adicione Taskfile com targets lint/test/build para TS e Go. Gere também READMEs por pasta e CODEOWNERS com as equipes @frontend, @mobile, @platform, @backend-go.”

Exemplo preenchido
“Use Nx 19+, pnpm 9+. Inclua apps web-next, mobile-expo, bff-nest, svc-accounts-go. Biome com regras estritas (no any, import/order). go.work usando Go 1.22. Taskfile com golangci-lint, govulncheck, pnpm biome. Gere docs/ADR-0001.md definindo padrões. Saída: diretórios e arquivos prontos para commit inicial.”


---

4.2 Agente Frontend (Next.js)

Template
“Gere um app Next.js (App Router) dentro de apps/web-next com layout padrão (header, sidebar responsiva), theme switch, rota /health consumindo BFF, OTel no client/server, middleware inserindo x-request-id.”

Exemplo
“Incluir páginas /(dashboard), /auth/signin, /(settings). Adotar PrimeReact/PrimeFlex. Integre fetch com traceparent. Testes com Vitest + Testing Library. next.config.mjs habilitando headers de segurança (CSP básica).”


---

4.3 Agente Mobile (Expo)

Template
“Crie apps/mobile-expo com navegação (tabs), secure storage de token, cliente HTTP com context de sessão, OTel expo-instrumentation, tela Health chamando BFF e exibindo traceId.”

Exemplo
“Tabs: Home, Health, Settings. Implementar deep links. EAS config para preview. Testes com Jest + React Native Testing Library.”


---

4.4 Agente BFF (Nest.js)

Template
“Gere apps/bff-nest com módulos CoreModule (logging pino, otel), AuthModule (JWT, RBAC), ApiModule (REST /health, /whoami), global pipes/filters/interceptors com correlação de trace, e guardian RBAC por rota. Exponha /metrics.”

Exemplo
“Incluir @nestjs/config com schema Zod. Criar Claims + Roles. Log estruturado por requisição com requestId. Testes e e2e (supertest).”


---

4.5 Agente Backend Go (Echo + Fx + Watermill)

Template
“Crie o serviço apps/svc-accounts-go com módulos Fx: Config, Logger(zap), Otel, HTTP(Echo), Events(Watermill). Exponha /health e tópico accounts.debited. Adicione middleware de trace (propagação).”

Exemplo
“Router Watermill com publisher e subscriber de teste. Endpoint /transfer publica evento; subscriber registra no log com traceId. Incluir Dockerfile distroless e Makefile/Taskfile.”


---

4.6 Agente Observabilidade

Template
“Gere configs de OTel Collector (otel-collector.yaml) recebendo OTLP:4317/4318, exportando para Tempo/Jaeger, Prometheus e Loki. Crie dashboards Grafana: Service Overview, API Latency, Go Routines, BFF Errors.”

Exemplo
“Dash: p95/p99 por rota, erro por status-code, throughput, span links entre web-next → bff-nest → svc-accounts-go. Alertas p/ erro >2% 5m.”


---

4.7 Agente Segurança

Template
“Adicione políticas: JWT (RS256), roles/claims, input validation (Zod/DTO), CSP, rate-limit, Helmet (Nest/Echo), scans (Semgrep/CodeQL), secret scanning (Gitleaks), SBOM (Syft), image scan (Trivy).”

Exemplo
“CSP bloqueando inline, allowlist de domínios; x-request-id obrigatório; deny by default em BFF; security headers no Next com headers().”


---

4.8 Agente Dados/Cache

Template
“Provisione libs/ts/cache (Redis adapter com interfaces), libs/go/pkg/cache (redis client), repositories com interface (porta). Incluir idempotência baseada em chave e outbox preparado (TS/Go).”

Exemplo
“Keybuilder com tenant|aggregate|id|ts. Retry com backoff exponencial. Testes de concorrência em Go (race detector).”


---

4.9 Agente DevOps/CI-CD

Template
“Crie workflows GitHub: ci.yml (matriz TS/Go), release-ts.yml (changesets), release-go.yml (goreleaser), path filters, cache (pnpm/go), Sonar, SBOM, Trivy, deploy (Vercel/Expo EAS/GHCR).”

Exemplo
“on: pull_request roda lint/test/scan; on: push tags dispara release; preview para branches em Next/Expo.”


---

4.10 Agente Release Manager

Template
“Implemente versionamento independente TS via Changesets; Go via tag por módulo. Gere CHANGELOGs por pacote/módulo e release notes agregados.”

Exemplo
“Publicar @org/framework-core@1.1.0 sem tocar apps; tag svc-accounts-go/v0.3.0 com binários multi-arch.”


---

4.11 Agente Testes & Qualidade

Template
“Crie suites: unit (TS/Go), integração (Nest+DB fake/containers), e2e (web→bff→svc-go). Coverage gate 80%, contract tests (OpenAPI).”

Exemplo
“Cenário transfer: web chama BFF, BFF chama svc-go, evento emitido e observado; traceId consistente no teste.”


---

4.12 Agente Documentação

Template
“Gere Docusaurus/Next docs, ADRs por mudança, C4 (Context/Container/Component) e runbooks (observabilidade, incident response, release).”

Exemplo
“C4 L3 do svc-accounts-go com componentes: HTTP, Event Router, UseCases, Repos, Adapters.”


---

5) Exemplos de Configuração (mínimos e pragmáticos)

5.1 package.json (root) + pnpm workspaces

{
  "name": "org-monorepo",
  "private": true,
  "packageManager": "pnpm@9.6.0",
  "scripts": {
    "dev": "pnpm nx run-many -t serve --parallel=3",
    "build": "pnpm nx run-many -t build",
    "test": "pnpm nx run-many -t test",
    "lint": "pnpm biome check .",
    "format": "pnpm biome check --write .",
    "changeset:version": "changeset version",
    "changeset:publish": "changeset publish"
  }
}

pnpm-workspace.yaml

packages:
  - "apps/*"
  - "libs/ts/*"

5.2 nx.json (trecho com run-commands para Go)

{
  "tasksRunnerOptions": {
    "default": {
      "runner": "@nx/workspace/tasks-runners/default",
      "options": { "cacheableOperations": ["build","test","lint"] }
    }
  },
  "targetDefaults": {
    "build": { "cache": true },
    "test": { "cache": true },
    "lint": { "cache": true }
  }
}

apps/svc-accounts-go/project.json (Go via run-commands)

{
  "name": "svc-accounts-go",
  "sourceRoot": "apps/svc-accounts-go",
  "targets": {
    "build": { "executor": "@nx/workspace:run-commands", "options": { "command": "task -d apps/svc-accounts-go build" } },
    "test":  { "executor": "@nx/workspace:run-commands", "options": { "command": "task -d apps/svc-accounts-go test" } },
    "serve": { "executor": "@nx/workspace:run-commands", "options": { "command": "task -d apps/svc-accounts-go run" } }
  }
}

apps/svc-accounts-go/Taskfile.yml

version: '3'
tasks:
  run: go run ./cmd
  build: go build -o bin/svc ./cmd
  test: go test ./... -race -cover
  lint: golangci-lint run && govulncheck ./...

5.3 biome.json (TS lint/format essencial)

{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "formatter": { "enabled": true },
  "linter": {
    "enabled": true,
    "rules": {
      "correctness": { "noUndeclaredVariables": "error" },
      "style": { "noVar": "error" },
      "suspicious": { "noExplicitAny": "error" }
    }
  }
}


---

6) Ramificações, Versionamento e Liberação

Branching (recomendado): Trunk-based com feature/*, hotfix/*. Pull Requests pequenos, feature flags.

Conventional Commits + Changesets:

Apps: podem “pinar” versões de libs; releases por app em pipelines dedicadas.

Libs TS: changeset por alteração; publicação independente.

Módulos Go: tags por módulo svc-accounts-go/vX.Y.Z; Goreleaser para binários.


Changelogs: por pacote e agregados no release final.



---

7) Critérios de Testabilidade e Observabilidade (DoD global)

Testes: unit ≥80%; integração E2E com trace propagation validada.

Observabilidade: cada request tem traceId visível ponta-a-ponta; dashboards com p95/err rate.

Segurança: scans sem CVEs de severidade alta; segredos ausentes no repo.

DX: generators funcionam; make/task unificados; nx graph atualizado.



---

8) Próximos Passos Recomendados (sequência prática)

1. Executar Etapas 0–1 e efetuar o primeiro commit “infra”.


2. Gerar libs TS & Go (Etapas 2–3) com os agentes 4.2–4.5.


3. Subir apps esqueleto (Etapa 4) e validar health-to-trace.


4. Habilitar observabilidade (Etapa 5) com compose local.


5. Configurar CI/CD (Etapa 6) e release (Etapa 7) com um corte inicial de versões.


6. Fechar lacunas de segurança/DX (Etapas 8–9) e publicar docs (Etapa 10).




---

9) Anexos — Prompts rápidos (one-liners úteis)

Gerar lib TS core:
“Crie libs/ts/framework-core com Result<T,E>, DomainError, Command/Query/Event, unit tests e index.ts exportando tudo; sem any, com JSDoc e exemplos.”

Novo serviço Go (Echo+Fx+Watermill):
“Gere apps/svc-X-go com Echo /health, Fx modules (Logger, Otel, HTTP, Events), Watermill router com publisher/subscriber de exemplo, testes e Dockerfile distroless.”

Middleware de tracing (Nest):
“Implemente interceptor global que injeta traceId no contexto de request e no logger; exponha /metrics; teste e doc.”

Pipeline CI minimal:
“Crie ci.yml com matriz TS/Go, caches, lint/test/scan, path filters por apps/ e libs/, e required checks.”