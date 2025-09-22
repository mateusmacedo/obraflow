# Extensão Multi-Tenant para o Plano do Monorepo (TS + Go)

Abaixo incorporo **multi-tenancy ponta-a-ponta** às etapas existentes — **identidade e resolução do tenant**, **propagação de contexto em HTTP/Eventos**, **isolamento de dados** (Postgres com *RLS* e *app settings*), **cache/filas/armazenamento**, **observabilidade** (traços/métricas/logs com `tenant.id`), **segurança/RBAC**, **DX (generators)**, **CI/CD** e **testabilidade** — com **exemplos completos** em **Nest/Next/Expo** (TypeScript) e **Echo+Fx+Watermill** (Go).
Mantive **Clean Arch, DDD, CQRS/EDA, SOLID**, baixo acoplamento e **contratos genéricos**.

---

## 1) Decisões de Tenancy (ADR-MT-0001)

### 1.1 Modelos suportados

* **Pooled (DB compartilhado)**: tabelas com `tenant_id` + **RLS** por tenant (default).
* **Schema-per-tenant**: schemas `t_<tenant>` para domínios com forte necessidade de isolamento.
* **Database-per-tenant**: casos de conformidade/regulatórios específicos.

**Regra:** escolher por **bounded context** (ex.: *Accounts* pooled com RLS; *Billing* schema-per-tenant). Documentar por ADR.

### 1.2 Origem do tenant

Ordem de resolução:

1. **JWT claim** `tid`;
2. **Subdomínio** `TENANT.myapp.com`;
3. **Header** `x-tenant-id` (apenas *trusted paths*).

**Validação**: `tid` ∈ *Tenant Registry* (cacheado). Rejeitar requisição se inválido.

---

## 2) Contratos Comuns (TS + Go)

### 2.1 Cabeçalhos / Metadados de contexto

* HTTP headers: `x-tenant-id`, `x-request-id`, `traceparent`.
* Eventos (Watermill/Kafka): `tenant-id`, `correlation-id`, `causation-id`.

### 2.2 Porta de Tenancy (TS)

`libs/ts/framework-core/src/tenancy/tenant-context.ts`

```ts
// Contrato agnóstico para obter/propagar tenant em qualquer camada.
export interface TenantContext {
  readonly id: string;               // Tenant canonical id
  readonly source: 'jwt'|'subdomain'|'header';
  readonly plan?: 'free'|'pro'|'enterprise';
}

export interface TenantResolver {
  resolveFromHttp(req: unknown): TenantContext | null;
}

export interface TenantPropagator {
  // Injeta tenant em headers/metadados de saída (HTTP/Eventos)
  inject(carrier: Record<string, unknown>, tenant: TenantContext): void;
}
```

### 2.3 Cabeçalhos em Eventos (Go)

`libs/go/pkg/events/metadata.go`

```go
package events

const (
    HeaderTenantID     = "tenant-id"
    HeaderCorrelation  = "correlation-id"
    HeaderCausation    = "causation-id"
)
```

---

## 3) Resolução e Propagação — TypeScript

### 3.1 Resolvedor de Tenant (Nest BFF)

`libs/ts/security/src/tenant/tenant.resolver.ts`

```ts
import type { TenantContext, TenantResolver } from "@org/framework-core/tenancy/tenant-context";
import type { Request } from "express";
import * as jose from "jose";

export class HttpTenantResolver implements TenantResolver {
  constructor(private readonly tenantRegistry: { has(id: string): Promise<boolean> }) {}

  public resolveFromHttp(req: Request): TenantContext | null {
    // 1) JWT (Authorization: Bearer ...)
    const auth = req.headers.authorization?.trim();
    if (auth?.startsWith("Bearer ")) {
      const token = auth.substring("Bearer ".length);
      try {
        // Verificação da assinatura é externa (AuthModule); aqui só lemos claims de maneira defensiva.
        const { payload } = jose.decodeJwt(token) as { payload?: unknown } as any;
        const tid = (payload as any)?.tid as string | undefined;
        if (tid) return { id: tid, source: "jwt" };
      } catch { /* ignore decode errors */ }
    }
    // 2) Subdomínio
    const host = req.headers.host ?? "";
    const sub = host.split(".")[0];
    if (sub && sub !== "www") return { id: sub, source: "subdomain" };

    // 3) Header x-tenant-id
    const headerTid = req.headers["x-tenant-id"] as string | undefined;
    if (headerTid) return { id: headerTid, source: "header" };

    return null;
  }
}
```

### 3.2 **AsyncLocalStorage** para escopo de requisição

`libs/ts/framework-core/src/tenancy/tenant.storage.ts`

```ts
import { AsyncLocalStorage } from "node:async_hooks";
import type { TenantContext } from "./tenant-context";

export class TenantStorage {
  private readonly als = new AsyncLocalStorage<TenantContext>();

  runWithTenant<T>(tenant: TenantContext, fn: () => T): T {
    return this.als.run(tenant, fn);
  }
  current(): TenantContext | undefined {
    return this.als.getStore();
  }
}
```

### 3.3 Middleware global (Nest)

`apps/bff-nest/src/infrastructure/http/tenant.middleware.ts`

```ts
import { Injectable, NestMiddleware, UnauthorizedException } from "@nestjs/common";
import { Request, Response, NextFunction } from "express";
import { HttpTenantResolver } from "@org/security/tenant/tenant.resolver";
import { TenantStorage } from "@org/framework-core/tenancy/tenant.storage";

@Injectable()
export class TenantMiddleware implements NestMiddleware {
  constructor(
    private readonly resolver: HttpTenantResolver,
    private readonly storage: TenantStorage,
    private readonly tenantRegistry: { has(id: string): Promise<boolean> }
  ) {}

  async use(req: Request, res: Response, next: NextFunction) {
    const ctx = this.resolver.resolveFromHttp(req);
    if (!ctx || !(await this.tenantRegistry.has(ctx.id))) {
      throw new UnauthorizedException("Invalid or missing tenant");
    }
    this.storage.runWithTenant(ctx, next);
  }
}
```

### 3.4 Decorator de Injeção (Nest)

`apps/bff-nest/src/infrastructure/http/tenant.decorator.ts`

```ts
import { createParamDecorator, ExecutionContext } from "@nestjs/common";
import { TenantStorage } from "@org/framework-core/tenancy/tenant.storage";

export const Tenant = createParamDecorator((_: unknown, ctx: ExecutionContext) => {
  const req = ctx.switchToHttp().getRequest();
  const storage: TenantStorage = req.app.get(TenantStorage);
  const t = storage.current();
  if (!t) throw new Error("Tenant not resolved");
  return t;
});
```

### 3.5 Propagação para *fetch/axios* (Next/Expo/Nest → Go)

`libs/ts/http-client/src/interceptors/tenant-propagator.ts`

```ts
import type { TenantPropagator, TenantContext } from "@org/framework-core/tenancy/tenant-context";

export class HeaderTenantPropagator implements TenantPropagator {
  inject(carrier: Record<string, unknown>, tenant: TenantContext): void {
    carrier["x-tenant-id"] = tenant.id;
  }
}
```

---

## 4) Resolução e Propagação — Go (Echo + Fx + Watermill)

### 4.1 Middleware Echo com `context.Context`

`libs/go/pkg/tenancy/middleware.go`

```go
package tenancy

import (
    "context"
    "net/http"
    "strings"

    "github.com/labstack/echo/v4"
)

type TenantContext struct {
    ID     string
    Source string // jwt|subdomain|header
    Plan   string // opcional
}

type ctxKey struct{}
var tenantKey ctxKey

func FromContext(ctx context.Context) (*TenantContext, bool) {
    t, ok := ctx.Value(tenantKey).(*TenantContext)
    return t, ok
}

type Registry interface {
    Has(ctx context.Context, id string) (bool, error)
}

func Middleware(reg Registry) echo.MiddlewareFunc {
    return func(next echo.HandlerFunc) echo.HandlerFunc {
        return func(c echo.Context) error {
            // 1) Header Authorization (JWT) - parse *levemente* (validação criptográfica fora)
            auth := c.Request().Header.Get("Authorization")
            if strings.HasPrefix(auth, "Bearer ") {
                if tid := parseTidFromJWT(strings.TrimPrefix(auth, "Bearer ")); tid != "" {
                    if ok, _ := reg.Has(c.Request().Context(), tid); ok {
                        ctx := context.WithValue(c.Request().Context(), tenantKey, &TenantContext{ID: tid, Source: "jwt"})
                        c.SetRequest(c.Request().WithContext(ctx))
                        return next(c)
                    }
                }
            }
            // 2) Subdomínio
            host := c.Request().Host
            sub := strings.Split(host, ".")[0]
            if sub != "" && sub != "www" {
                if ok, _ := reg.Has(c.Request().Context(), sub); ok {
                    ctx := context.WithValue(c.Request().Context(), tenantKey, &TenantContext{ID: sub, Source: "subdomain"})
                    c.SetRequest(c.Request().WithContext(ctx))
                    return next(c)
                }
            }
            // 3) Header
            tid := c.Request().Header.Get("x-tenant-id")
            if tid != "" {
                if ok, _ := reg.Has(c.Request().Context(), tid); ok {
                    ctx := context.WithValue(c.Request().Context(), tenantKey, &TenantContext{ID: tid, Source: "header"})
                    c.SetRequest(c.Request().WithContext(ctx))
                    return next(c)
                }
            }
            return c.NoContent(http.StatusUnauthorized)
        }
    }
}

// parseTidFromJWT: leitura defensiva (sem validação criptográfica)
func parseTidFromJWT(token string) string {
    // Implementação mínima: decodificar payload base64 e extrair "tid"
    // ... (omisso: código de parse base64url e JSON strictly typed)
    return ""
}
```

### 4.2 Propagação para Watermill

`apps/svc-accounts-go/internal/events/publish.go`

```go
msg := message.NewMessage(watermill.NewUUID(), payloadBytes)
if tctx, ok := tenancy.FromContext(ctx); ok {
    msg.Metadata.Set(events.HeaderTenantID, tctx.ID)
}
msg.Metadata.Set(events.HeaderCorrelation, corrID)
msg.Metadata.Set(events.HeaderCausation, causID)
if err := publisher.Publish("accounts.debited", msg); err != nil { /* ... */ }
```

---

## 5) Isolamento de Dados — Postgres com **RLS** + `app.tenant_id`

### 5.1 Migração SQL (base segura)

`db/migrations/0001_tenancy.sql`

```sql
-- Tabela de tenants
CREATE TABLE IF NOT EXISTS public.tenants (
  id       text PRIMARY KEY,
  name     text NOT NULL,
  plan     text NOT NULL DEFAULT 'free',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Exemplo de tabela multi-tenant (pooled)
CREATE TABLE IF NOT EXISTS public.accounts (
  id           uuid PRIMARY KEY,
  tenant_id    text NOT NULL REFERENCES public.tenants(id),
  owner_id     uuid NOT NULL,
  balance_cents bigint NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Habilita RLS
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

-- Definição de parâmetro por sessão: app.tenant_id
-- (Será setado por conexão ao iniciar a requisição)
CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS text LANGUAGE sql AS $$ SELECT current_setting('app.tenant_id', true) $$;

-- Política: só enxerga linhas do tenant atual
CREATE POLICY rls_accounts_isolation ON public.accounts
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());
```

### 5.2 **SET app.tenant\_id** por requisição

#### Nest (TypeORM DataSource wrapper — opcional)

```ts
// Ao adquirir um queryRunner/connection para a request:
await runner.query(`SET app.tenant_id = $1`, [tenant.id]);
// a partir daí, SELECT/INSERT/UPDATE obedecem RLS automaticamente
```

#### Go (pgx)

```go
conn, err := pool.Acquire(ctx)
if err != nil { /* ... */ }
defer conn.Release()
if tctx, ok := tenancy.FromContext(ctx); ok {
    _, _ = conn.Exec(ctx, "SET app.tenant_id = $1", tctx.ID)
}
// operações subsequentes já passam pelo RLS
```

> **Vantagens**: evita *where tenant\_id* espalhado, reduz erro humano; RLS é aplicado tanto em leitura quanto gravação por política.

---

## 6) Cache/Armazenamento/Filas

### 6.1 Redis (key-scoping)

* `key = ${tenantId}:${boundedContext}:${entity}:${id}`
* Definir *TTL* e *rate limiters* por tenant.

### 6.2 S3/Blob

* Prefixos: `tenants/<tenantId>/...` + *bucket policies* opcionais por prefixo.

### 6.3 Kafka/NATS

* **Key** de particionamento: `${tenantId}|${aggregateId}`
* Tópicos podem ser **globais** com *metadata* `tenant-id` (**preferível**) para reduzir *topic explosion*.

---

## 7) Observabilidade (OTel/Loki/Prometheus)

### 7.1 Atributos padronizados

* **Resource / Span / Log attributes**:
  `tenant.id`, `tenant.plan`, `user.id`, `session.id`.

### 7.2 TS — Pino + OTel

```ts
logger.info({ tenantId: storage.current()?.id, route, status }, "request.ok");
```

Registradores devem incluir `tenantId` como **binding** por requisição.

### 7.3 Go — Zap + OTel

```go
if tctx, ok := tenancy.FromContext(ctx); ok {
    logger = logger.With(zap.String("tenant.id", tctx.ID))
}
```

### 7.4 Dashboards

* *Service Overview* com **filtros por `tenant.id`** (p95/p99, error rate, throughput).
* *Multitenant Heatmap*: picos por tenant (detecção de *noisy neighbor*).

---

## 8) Segurança & RBAC Multi-tenant

* **JWT claims**: `tid` (obrigatório), `roles` com escopo (`tenant:admin`, `tenant:user`).
* **Guards** validam que o acesso ao recurso pertence ao `tid` atual.
* **CSP/Helmet** já previstos; **rate-limit** por `tenant.id`.

Exemplo Guard (Nest):

```ts
import { CanActivate, ExecutionContext, ForbiddenException } from "@nestjs/common";
import { TenantStorage } from "@org/framework-core/tenancy/tenant.storage";

export class TenantScopeGuard implements CanActivate {
  constructor(private readonly storage: TenantStorage) {}
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const user = req.user as { roles?: string[] } | undefined;
    const tenant = this.storage.current();
    if (!tenant) throw new ForbiddenException("No tenant");

    const roles = user?.roles ?? [];
    const allowed = roles.some(r => r === "tenant:admin" || r === `tenant:${tenant.id}:admin`);
    if (!allowed) throw new ForbiddenException("Insufficient role");
    return true;
  }
}
```

---

## 9) DX — **Generators** multi-tenant (Nx/Task)

### 9.1 TS — gerador de *feature* tenant-aware

`tools/generators/feature-tenant/index.ts` (esqueleto)

* Cria: `Module`, `Controller`, `Service`, `E2E test`, **interceptor** que injeta `tenantId` em *axios/fetch* e guarda *ALS*.
* Gera contrato `Repository` com *filters* obrigatórios por tenant (quando **não** usar RLS).

### 9.2 Go — `task g:svc -n svc-<name>-go`

* Cria `internal/tenancy` *wiring*, *Echo middleware*, *Watermill publisher/subscriber* com `tenant-id`.

---

## 10) CI/CD — sementes e validações

* **Seed dev**: `tenants` A/B/Enterprise.
* **Quality gate**: testes E2E **multitenant** (A não vê dados de B).
* **Políticas**: pipelines falham se requisições críticas não propagarem `tenant.id` (testes de contrato).

---

## 11) Testabilidade (DoD MT)

* **Unit**: resolvers (JWT/subdomínio/header), propagators (headers/eventos).
* **Integration**: Postgres com RLS + `SET app.tenant_id`.
* **E2E**: web→bff→svc-go com *trace* e `tenant.id` coerente; validação de isolamento.
* **Carga**: *noisy neighbor* com limites/quotas por tenant.

---

## 12) Exemplos completos (mínimos, prontos)

### 12.1 **Nest Controller** com Tenant Decorator

`apps/bff-nest/src/api/whoami.controller.ts`

```ts
import { Controller, Get, UseGuards } from "@nestjs/common";
import { Tenant } from "../infrastructure/http/tenant.decorator";
import { TenantScopeGuard } from "../infrastructure/security/tenant-scope.guard";

@Controller("whoami")
@UseGuards(TenantScopeGuard)
export class WhoAmIController {
  @Get()
  get(@Tenant() t: { id: string; source: string }) {
    return { tenant: t.id, source: t.source, ok: true };
  }
}
```

### 12.2 **Echo route** com leitura de tenant

`apps/svc-accounts-go/cmd/main.go` (trecho)

```go
e := echo.New()
e.Use(tenancy.Middleware(registry))
e.GET("/health", func(c echo.Context) error {
    if tctx, ok := tenancy.FromContext(c.Request().Context()); ok {
        return c.JSON(200, map[string]string{"ok":"true","tenant":tctx.ID})
    }
    return c.JSON(200, map[string]string{"ok":"true"})
})
```

### 12.3 **Propagação** Next → BFF

`libs/ts/http-client/src/fetch.ts`

```ts
import { TenantStorage } from "@org/framework-core/tenancy/tenant.storage";
import { HeaderTenantPropagator } from "./interceptors/tenant-propagator";

const storage = new TenantStorage();
const propagator = new HeaderTenantPropagator();

export async function tfetch(input: RequestInfo, init: RequestInit = {}) {
  const t = storage.current();
  const headers: Record<string, unknown> = { ...(init.headers as any) };
  if (t) propagator.inject(headers, t);
  return fetch(input, { ...init, headers: headers as HeadersInit });
}
```

---

## 13) Observabilidade — OTel *resource* por tenant

### 13.1 TS (início de request)

```ts
import { context, trace, Span, SpanStatusCode } from "@opentelemetry/api";
import { TenantStorage } from "@org/framework-core/tenancy/tenant.storage";

const storage = new TenantStorage();

export function annotateSpanWithTenant(span: Span) {
  const t = storage.current();
  if (t) {
    span.setAttribute("tenant.id", t.id);
    span.setAttribute("tenant.source", t.source);
  }
}
```

### 13.2 Go (middleware de span)

```go
if span := trace.SpanFromContext(ctx); span != nil {
    if tctx, ok := tenancy.FromContext(ctx); ok {
        span.SetAttributes(attribute.String("tenant.id", tctx.ID))
    }
}
```

---

## 14) Próximas Etapas (complementares ao seu item 8)

1. **Etapa 0.5 — ADR/RFC Multi-Tenant**:

   * ADR-MT-0001 (modelo por domínio), ADR-MT-0002 (origem/precedência), RFC-MT-0001 (RLS + `app.tenant_id` + padrões de chave Redis/Kafka).
   * *Aceite*: ADRs aprovadas e linter de políticas habilitado.

2. **Etapa 2.5 — Tenancy TS**:

   * `TenantStorage`, `TenantResolver`, middleware/guard/decorator, propagator http.
   * *Aceite*: *whoami* retorna `tenant.id`; requisições saem com `x-tenant-id`.

3. **Etapa 3.5 — Tenancy Go**:

   * Middleware Echo, integração pgx `SET app.tenant_id`, Watermill metadata.
   * *Aceite*: eventos incluem `tenant-id`; RLS efetiva.

4. **Etapa 5.5 — Observabilidade Tenant**:

   * `tenant.id` em spans/logs/metrics; dashboards com filtro por tenant.
   * *Aceite*: p95/error-rate por tenant.

5. **Etapa 6.5 — CI/CD Tenant**:

   * Seeds/migrations por tenant dev; E2E multi-tenant obrigatório.
   * *Aceite*: PR quebra se teste E2E detectar *leak* entre tenants.

6. **Etapa 9.5 — Generators Tenant**:

   * Nx/Task gerando *feature/service* já com resolvers/propagators/tests.
   * *Aceite*: “um comando” cria endpoint/handler com tenant aplicado.

---

## 15) Prompts Operacionais (multi-tenant)

**Agente BFF (Nest) – ativar tenancy**

> “Implemente TenantMiddleware, TenantStorage (AsyncLocalStorage) e TenantScopeGuard em `apps/bff-nest`. Resolva o tenant por JWT `tid`, subdomínio e header `x-tenant-id` (nessa ordem). Rejeite inválidos. Exporte decorator `@Tenant()` e ajuste `/whoami`. Propague `x-tenant-id` no cliente HTTP interno.”

**Agente Backend Go – RLS + propagação**

> “No `apps/svc-accounts-go`, adicione middleware tenancy (Echo), `SET app.tenant_id` no pgx antes de queries, e inclua `tenant-id` nos metadados Watermill. Crie migração SQL com RLS conforme `db/migrations/0001_tenancy.sql`.”

**Agente Observabilidade – atributos de tenant**

> “Configure OTel (TS/Go) para adicionar `tenant.id` nos spans/logs. Atualize dashboards Grafana para permitir filtro por `tenant.id` e alarme de *error rate > 2%/5m* por tenant.”

**Agente Testes – E2E multi-tenant**

> “Crie cenários A/B: gerar dados em A e validar ausência em B (HTTP e eventos). Verificar traço contendo `tenant.id` em cada hop (web→bff→svc).”

---

## 16) Notas de Segurança & Compliance

* **Header `x-tenant-id` só é aceito em rotas internas** ou quando + *mutual-TLS / gateway confiável*.
* **JWT assinado (RS256)** é a fonte preferencial.
* **RLS** aplicado **sempre** que possível; quando não aplicável (NoSQL), **prefixos/coleções por tenant** + *guards* de verificação.
* **Quotas** por tenant (req/s, storage, eventos) – base para *rate limiting* e *billing* futuro.

---

## 17) Critérios de Aceite (multi-tenant, adicionais ao DoD)

* **Isolamento**: testes E2E demonstram que **dados não vazam** entre tenants.
* **Propagação**: `tenant.id` presente em **headers**, **eventos**, **spans** e **logs**.
* **Rastreabilidade**: dashboards permitem **filtrar por tenant**; incidentes mostram impacto por tenant.
* **Segurança**: RBAC respeita escopo do tenant; rejeições corretas para `tid` inválido.

---

### Encerrando

Com esses artefatos e exemplos, seu monorepo passa a ter **multi-tenancy de ponta a ponta**, mantendo **Clean Arch, DDD, CQRS/EDA, observabilidade, segurança e testabilidade**.
Se quiser, prossigo gerando **(a)** os **generators Nx/Task** prontos, **(b)** as **migrations/seeders** completas por domínio, ou **(c)** os **dashboards Grafana** com variáveis de `tenant.id`.
