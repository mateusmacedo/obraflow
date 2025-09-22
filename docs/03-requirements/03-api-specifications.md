# Manifesto 5 — **API Governance (REST/OpenAPI & GraphQL) + Resiliência & Contratos**

*(ObraFlow · pacote inicial, pronto para colar no repositório)*

Este pacote padroniza **estilo de API**, **segurança**, **versionamento**, **erros (RFC 7807)**, **paginação/filtragem**, **idempotência**, **caching/ETag/condicional**, **limitação/quotas**, **testes de contrato** e **observabilidade de API**, cobrindo **REST (OpenAPI 3.1)** e **GraphQL** (com gateway/BFF). Está alinhado aos Manifestos 1–4 (NFR/SLO, eventos, segurança, observabilidade).

---

## 📁 Estrutura de arquivos

```
docs/
  10-architecture/
    api-governance/
      README.md
      style-guide.md
      error-model-rfc7807.json
      pagination-filtering.md
      versioning.md
      resiliency.md
      caching-conditional.md
      security.md
      observability.md
      testing-contracts.md
      lint/
        spectral.yaml
      rest/
        openapi.yml
        examples/
          work-orders.http
      graphql/
        schema.graphql
        operations/
          queries.graphql
          mutations.graphql
        guidelines.md
      ci/
        contract-verify.sh
        prism-mock.docker-compose.yml
```

---

## 1) `README.md` — Visão Geral

```markdown
# API Governance — ObraFlow

Padrões e contratos para APIs **REST** (OpenAPI 3.1) e **GraphQL** (BFF).
Foco em **compatibilidade**, **resiliência**, **segurança** e **observabilidade**.

## Como usar
1) Abra `style-guide.md` (nomenclatura/padrões).
2) Use `rest/openapi.yml` como **fonte única de verdade** para REST.
3) Se usar GraphQL no BFF, siga `graphql/schema.graphql` + `guidelines.md`.
4) Erros padronizados em `error-model-rfc7807.json`.
5) Publique mocks com `ci/prism-mock.docker-compose.yml`.
6) Valide CI com `lint/spectral.yaml` e `ci/contract-verify.sh`.
```

---

## 2) `style-guide.md` — Guia de Estilo

```markdown
# Guia de Estilo de API

## Convenções REST
- **Base path**: `/api/v1` (versionamento obrigatório)
- **Recursos**: `kebab-case` nos paths; substantivos no plural (`/work-orders`).
- **IDs**: estáveis, opacos, string ULID/UUID (validação regex obrigatória).
- **Operações**
  - GET `/resource` (coleção, paginação cursor obrigatória)
  - GET `/resource/{id}` (detalhe, validação de ID obrigatória)
  - POST `/resource` (criação, exige `Idempotency-Key` e validação de payload)
  - PATCH `/resource/{id}` (parcial, JSON Merge Patch RFC 7396, validação de campos)
  - PUT (quando substituição total é semântica, validação completa)
  - DELETE (remoção lógica quando aplicável, confirmação obrigatória)
- **Validação**: Todos os endpoints devem validar entrada com schemas OpenAPI + Zod/Joi
- **Sanitização**: Input sanitization obrigatório para prevenir injection attacks

## Campos & JSON
- `camelCase` em chaves JSON; datas em **ISO8601 UTC**.
- Enum como string; números com unidade explícita em `uom` quando necessário.

## Filtros & Busca
- `?filter[field]=value` e `?q=` (full-text).
- Campos múltiplos: `?filter[status]=SCHEDULED,IN_PROGRESS`
- Intervalos: `?filter[plannedStart][gte]=2025-09-22T07:00:00Z`

## HATEOAS (mínimo)
- `links.self`, `links.next`, `links.prev` em coleções.
```

---

## 3) `error-model-rfc7807.json` — Erros Padronizados

```json
{
  "$id": "https://obraflow.example/schemas/api/error-model-rfc7807.json#1.0.0",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "ProblemDetails (RFC 7807)",
  "type": "object",
  "required": ["type", "title", "status", "traceId"],
  "properties": {
    "type": {"type": "string", "format": "uri"},
    "title": {"type": "string"},
    "status": {"type": "integer", "minimum": 100, "maximum": 599},
    "detail": {"type": "string"},
    "instance": {"type": "string"},
    "traceId": {"type": "string"},
    "correlationId": {"type": "string"},
    "errors": {
      "type": "array",
      "items": { "type": "object", "properties": {
        "field": {"type": "string"},
        "message": {"type": "string"},
        "code": {"type": "string"}
      }}
    }
  },
  "additionalProperties": false
}
```

---

## 4) `pagination-filtering.md`

````markdown
# Paginação, Ordenação e Filtro

## Paginação por cursor (recomendado)
- Requisição: `GET /work-orders?limit=50&cursor=eyJwYWdlIjoyfQ==`
- Resposta:
```json
{
  "data":[{ "...": "..." }],
  "page": { "limit": 50, "nextCursor": "base64", "prevCursor": "base64" },
  "links": { "self": "...", "next": "...", "prev": "..." }
}
````

## Ordenação

* `?sort=-plannedStart,title` (prefixo `-` = desc)

## Filtragem

* `?filter[status]=SCHEDULED,IN_PROGRESS`
* `?filter[siteId]=obra-sp-01`
* `?filter[plannedStart][gte]=2025-09-22T07:00:00Z`

````

---

## 5) `versioning.md`

```markdown
# Versionamento

## REST API
- **Path versioning**: `/api/v1` (obrigatório)
- **Breaking changes**: Mudança **breaking** → `v2` (migration guide obrigatório)
- **Deprecation policy**: 6 meses de aviso para breaking changes
- **Backward compatibility**: v1 deve funcionar por 12 meses após v2
- **Migration tools**: Scripts automáticos para migração de clientes

## GraphQL
- **Schema evolution**: additive-only (novos campos opcionais)
- **Deprecation**: `@deprecated(reason:"...", sunsetAt:"2026-06-30")`
- **Breaking changes**: Novo schema major (v2) com migration guide
- **Field removal**: 6 meses de deprecation antes da remoção

## Eventos assíncronos
- **Topic versioning**: `.v1` (ver Manifesto 2)
- **Schema registry**: Compatibilidade BACKWARD obrigatória
- **Migration**: Ferramentas automáticas para migração de consumidores

## Compatibilidade
- **Additive only**: Novos campos sempre opcionais
- **Remoções**: Exigem major version + migration guide
- **Type changes**: Exigem major version
- **Validation**: Schema registry com validação obrigatória
````

---

## 6) `resiliency.md`

```markdown
# Resiliência de API

## Timeouts
- **HTTP**: 2s (default), 5s (mobile sync), 30s (bulk operations)
- **gRPC**: 1s (intra-service), 3s (external)
- **Database**: 5s (query), 30s (transaction)
- **Circuit breaker**: 5s (half-open state)

## Retry/Backoff
- **Exponential backoff**: 100ms, 250ms, 600ms, 1.5s (max 3 tentativas)
- **Jitter**: ±25% para evitar thundering herd
- **Retryable errors**: 429, 502-504, 408, 503
- **Non-retryable**: 400, 401, 403, 404, 422

## Idempotência
- **Header obrigatório**: `Idempotency-Key` em POST/PATCH críticos
- **Backend storage**: Redis com TTL 24h para replay-safe
- **Key format**: `{operation}-{tenant}-{hash}` (ex: `wo-create-acme-abc123`)
- **Response caching**: 201 responses cached por 1h

## Rate Limiting
- **Headers**: `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset`
- **Per tenant**: 1000 req/min (default), 100 req/min (mobile)
- **Per endpoint**: 100 req/min (heavy operations)
- **Burst**: 2x limit por 1 minuto

## Circuit Breaker
- **Failure threshold**: 5 falhas consecutivas
- **Recovery time**: 30s (half-open state)
- **Status**: 503 + `Retry-After` header
- **Monitoring**: Métricas de abertura/fechamento

## Bulkhead
- **Connection pools**: Separados por tenant/integração
- **Thread pools**: Isolados por operação crítica
- **Memory limits**: Por tenant para evitar OOM

## Concorrência
- **ETag/If-Match**: Controle otimista obrigatório
- **Version field**: Incremento automático em updates
- **Conflict resolution**: Last-write-wins com audit trail
```

---

## 7) `caching-conditional.md`

```markdown
# Caching & Condicionais

- **ETag** forte para recursos individuais.
- **GET condicional**: `If-None-Match` → 304 (economia para mobile).
- **Cache-Control**: coleções `no-store`; itens `max-age=15s, stale-while-revalidate=60`.
- **Delta Sync**: `If-Modified-Since`/`If-None-Match` em endpoints de sincronização.
```

---

## 8) `security.md`

```markdown
# Segurança

## Autenticação
- **OIDC/OAuth2**: Bearer token obrigatório
- **Scopes**: Granulares por tenant/obra (`tenant:read`, `site:write`)
- **Token validation**: JWT signature + expiration + issuer
- **Refresh tokens**: Rotação automática a cada 15min
- **Session management**: Revogação imediata em logout

## Transporte
- **TLS**: 1.3+ obrigatório (1.2+ deprecated)
- **mTLS**: Interno (service mesh) com certificados rotativos
- **HSTS**: Headers obrigatórios com max-age 1 ano
- **Certificate pinning**: Mobile apps com pinning estático

## Headers de Segurança
- **Obrigatórios**: `x-tenant-id`, `x-request-id`
- **Opcionais**: `x-site-id`, `x-user-role`
- **Validação**: Regex strict para todos os headers
- **Sanitização**: XSS prevention em todos os inputs

## Autorização
- **RBAC**: Roles baseados em tenant/obra
- **ABAC**: OPA/Rego policies (ver Manifesto 3)
- **Resource-level**: Controle fino por recurso
- **Audit**: Log de todas as decisões de autorização

## PII Protection
- **Logs**: Proibição total de PII
- **Analytics**: Mascaramento automático
- **Payloads**: Redaction em responses de erro
- **Storage**: Criptografia de campos sensíveis

## Input Validation
- **Schemas**: OpenAPI + Zod/Joi obrigatório
- **Size limits**: 1MB (default), 10MB (uploads)
- **Rate limiting**: Por tenant + endpoint
- **SQL injection**: Parameterized queries obrigatório

## Headers de Segurança
- **CORS**: Origins específicos, credentials: true
- **CSP**: Nonce-based, strict-dynamic
- **X-Frame-Options**: DENY
- **X-Content-Type-Options**: nosniff
- **Referrer-Policy**: strict-origin-when-cross-origin
```

---

## 9) `observability.md`

```markdown
# Observabilidade de API

## Atributos Obrigatórios
- **Tracing**: `trace_id`, `span_id`, `parent_span_id`
- **Correlation**: `correlation_id`, `request_id`
- **Tenant**: `tenant_id`, `site_id`, `user_id`
- **API**: `endpoint`, `method`, `version`, `client_id`

## Métricas RED por Rota
- **Rate**: Requests por segundo por endpoint
- **Errors**: 4xx/5xx rate por endpoint
- **Duration**: p50, p95, p99 latência por endpoint
- **Business**: Success rate, timeout rate, circuit breaker status

## Métricas de Negócio
- **Work Orders**: Criação, atualização, conclusão por tenant
- **Sync**: Mobile sync success rate, staleness por site
- **Resources**: Alocação, disponibilidade, custo por obra
- **AI/ML**: Inference latency, cost per request, accuracy

## Logs Estruturados
- **Format**: JSON com OpenTelemetry attributes
- **Levels**: ERROR, WARN, INFO, DEBUG (por endpoint)
- **Sampling**: 100% errors, 10% info, 1% debug
- **Retention**: 30d (info), 90d (errors), 1y (audit)

## Problemas (RFC 7807)
- **TraceId**: Obrigatório para correlation
- **CorrelationId**: Para rastreamento de request
- **Error codes**: Padronizados por domínio
- **Context**: Tenant, site, user em todos os erros

## Alertas
- **Latency**: p95 > 2s por endpoint
- **Error rate**: > 5% por endpoint
- **Circuit breaker**: Abertura por tenant
- **Rate limit**: 90% do limite por tenant
```

---

## 10) `testing-contracts.md`

```markdown
# Testes de Contrato e Mock

## Linting e Validação
- **Spectral**: Regras customizadas no CI (obrigatório)
- **OpenAPI**: Validação de schema + examples
- **GraphQL**: Schema validation + query complexity
- **RFC 7807**: Validação de error responses
- **Security**: OWASP API Security Top 10 checks

## Mock e Testes
- **Prism**: Mock server para desenvolvimento local
- **Contract testing**: Pact para consumer-driven contracts
- **Schema registry**: Validação de compatibilidade
- **Versioning**: Testes de backward compatibility

## Consumer-Driven Contracts (CDC)
- **Approval process**: Consumidores aprovam mudanças via PR
- **CODEOWNERS**: Proteção de endpoints críticos
- **Breaking changes**: Requer approval de todos os consumidores
- **Migration**: Scripts automáticos para breaking changes

## Testes E2E
- **k6**: Load testing de rotas críticas
- **Synthetic**: Monitoramento contínuo de endpoints
- **Mobile sync**: Testes específicos de sincronização
- **Error scenarios**: Testes de circuit breaker e rate limiting

## Validação de Segurança
- **SAST**: Análise estática de código
- **DAST**: Testes dinâmicos de segurança
- **Penetration**: Testes de penetração automatizados
- **Compliance**: Verificação de LGPD e ISO 27001
```

---

## 11) `lint/spectral.yaml` — Regras (excerto)

```yaml
extends: ["spectral:recommended", "spectral:oas", "@stoplight/spectral-ruleset"]
rules:
  # Tags e Documentação
  operation-tags:
    description: "Operações devem ter pelo menos uma tag"
    message: "Add at least one tag"
    given: "$.paths..[get,post,put,patch,delete]"
    then:
      field: "tags"
      function: truthy
  operation-description:
    description: "Operações devem ter descrição"
    given: "$.paths..[get,post,put,patch,delete]"
    then:
      field: "description"
      function: truthy
  operation-summary:
    description: "Operações devem ter summary"
    given: "$.paths..[get,post,put,patch,delete]"
    then:
      field: "summary"
      function: truthy

  # RFC 7807 Error Handling
  require-problem-details:
    description: "Erros devem usar RFC7807"
    given: "$.paths..responses[?(@property >= 400)].content.application/problem+json.schema"
    then:
      function: truthy
  error-response-required:
    description: "Todas as operações devem ter responses de erro"
    given: "$.paths..[get,post,put,patch,delete]"
    then:
      field: "responses"
      function: truthy

  # ID Validation
  no-integer-ids:
    description: "IDs opacos, não inteiros"
    given: "$.components.schemas..properties[*]"
    then:
      function: pattern
      functionOptions:
        match: "^(?!.*\"type\"\\s*:\\s*\"integer\").*$"
  id-format-validation:
    description: "IDs devem seguir formato ULID/UUID"
    given: "$.components.schemas..properties.id"
    then:
      function: pattern
      functionOptions:
        match: "^[0-9A-HJKMNP-TV-Z]{26}$|^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

  # Security
  security-required:
    description: "Todas as operações devem ter security definido"
    given: "$.paths..[get,post,put,patch,delete]"
    then:
      field: "security"
      function: truthy
  oauth2-scopes:
    description: "OAuth2 deve ter scopes definidos"
    given: "$.components.securitySchemes.oauth2.flows"
    then:
      function: truthy

  # Versioning
  version-in-path:
    description: "Paths devem incluir versão"
    given: "$.paths"
    then:
      function: pattern
      functionOptions:
        match: "^/api/v[0-9]+/"

  # Rate Limiting
  rate-limit-headers:
    description: "Rate limiting deve ter headers apropriados"
    given: "$.paths..responses.200.headers"
    then:
      field: "RateLimit-Limit"
      function: truthy

  # Pagination
  pagination-cursor:
    description: "Listas devem usar paginação cursor"
    given: "$.paths..get.responses.200.content.application/json.schema.properties"
    then:
      field: "page"
      function: truthy

  # Idempotency
  idempotency-key:
    description: "POST/PATCH devem ter Idempotency-Key header"
    given: "$.paths..[post,patch]"
    then:
      field: "parameters[?(@.name == 'Idempotency-Key')]"
      function: truthy

  # ETag
  etag-headers:
    description: "GET/PATCH devem ter ETag headers"
    given: "$.paths..[get,patch].responses.200.headers"
    then:
      field: "ETag"
      function: truthy
```

---

## 12) `rest/openapi.yml` — Catálogo REST (amostra completa funcional)

```yaml
openapi: 3.1.0
info:
  title: ObraFlow REST API
  version: 1.0.0
servers:
  - url: https://api.obraflow.example/api/v1
security:
  - oauth2: [tenant.read, tenant.write, site.read, site.write]
tags:
  - name: WorkOrders
    description: Ordens de Serviço
  - name: Sync
    description: Endpoints de sincronização mobile

paths:
  /work-orders:
    get:
      tags: [WorkOrders]
      summary: Listar OS
      parameters:
        - in: query
          name: limit
          schema: { type: integer, minimum: 1, maximum: 200, default: 50 }
        - in: query
          name: cursor
          schema: { type: string }
        - in: query
          name: filter[status]
          schema: { type: string, description: "CSV de status" }
        - in: query
          name: filter[siteId]
          schema: { type: string }
        - in: query
          name: sort
          schema: { type: string, example: "-plannedStart,title" }
      responses:
        "200":
          description: OK
          headers:
            RateLimit-Limit: { schema: { type: integer } }
            RateLimit-Remaining: { schema: { type: integer } }
            RateLimit-Reset: { schema: { type: integer } }
          content:
            application/json:
              schema:
                type: object
                required: [data, page]
                properties:
                  data:
                    type: array
                    items: { $ref: "#/components/schemas/WorkOrder" }
                  page:
                    type: object
                    properties:
                      limit: { type: integer }
                      nextCursor: { type: string, nullable: true }
                      prevCursor: { type: string, nullable: true }
                  links:
                    type: object
                    properties:
                      self: { type: string }
                      next: { type: string, nullable: true }
                      prev: { type: string, nullable: true }
        "400": { $ref: "#/components/responses/Problem400" }
        "401": { $ref: "#/components/responses/Problem401" }
        "403": { $ref: "#/components/responses/Problem403" }
    post:
      tags: [WorkOrders]
      summary: Criar OS
      parameters:
        - in: header
          required: true
          name: Idempotency-Key
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: "#/components/schemas/WorkOrderCreate" }
      responses:
        "201":
          description: Criado
          headers:
            ETag: { schema: { type: string } }
            Location: { schema: { type: string } }
          content:
            application/json:
              schema: { $ref: "#/components/schemas/WorkOrder" }
        "409": { $ref: "#/components/responses/Problem409" }
        "422": { $ref: "#/components/responses/Problem422" }

  /work-orders/{id}:
    get:
      tags: [WorkOrders]
      summary: Detalhar OS
      parameters:
        - in: path
          name: id
          required: true
          schema: { type: string }
        - in: header
          name: If-None-Match
          schema: { type: string }
      responses:
        "200":
          description: OK
          headers:
            ETag: { schema: { type: string } }
          content:
            application/json:
              schema: { $ref: "#/components/schemas/WorkOrder" }
        "304":
          description: Não modificado
        "404": { $ref: "#/components/responses/Problem404" }
    patch:
      tags: [WorkOrders]
      summary: Atualizar parcialmente (JSON Merge Patch)
      parameters:
        - in: path
          name: id
          required: true
          schema: { type: string }
        - in: header
          name: If-Match
          required: true
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/merge-patch+json:
            schema:
              type: object
      responses:
        "200": { $ref: "#/components/responses/Patched" }
        "409": { $ref: "#/components/responses/Problem409" }

  /sync/delta:
    get:
      tags: [Sync]
      summary: Delta de sincronização (mobile)
      parameters:
        - in: header
          name: If-Modified-Since
          schema: { type: string, format: date-time }
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema:
                type: object
                properties:
                  since: { type: string, format: date-time }
                  changes: { type: array, items: { type: object } }
        "304": { description: "Sem mudanças" }

components:
  securitySchemes:
    oauth2:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: https://idp.example/auth
          tokenUrl: https://idp.example/token
          scopes:
            tenant.read: "Ler dados do tenant"
            tenant.write: "Escrever dados do tenant"
            site.read: "Ler dados da obra"
            site.write: "Escrever dados da obra"
  schemas:
    WorkOrder:
      type: object
      required: [id, title, status, plannedWindow]
      properties:
        id: { type: string }
        title: { type: string }
        status: { type: string, enum: ["SCHEDULED","IN_PROGRESS","BLOCKED","DONE","CANCELLED"] }
        wbsPath: { type: string }
        plannedWindow:
          type: object
          required: [start, end]
          properties:
            start: { type: string, format: date-time }
            end: { type: string, format: date-time }
        resources:
          type: object
          properties:
            crew: { type: array, items: { type: object, properties: { skill: {type: "string"}, qty: {type: "number"} }, required: ["skill","qty"] } }
            equipment: { type: array, items: { type: object, properties: { type: {type: "string"}, qty: {type: "number"} }, required: ["type","qty"] } }
            materials: { type: array, items: { type: object, properties: { sku: {type: "string"}, qty: {type: "string"} }, required: ["sku","qty"] } }
    WorkOrderCreate:
      type: object
      required: [title, plannedWindow]
      properties:
        title: { type: string, minLength: 3 }
        wbsPath: { type: string }
        plannedWindow:
          type: object
          required: [start, end]
          properties:
            start: { type: string, format: date-time }
            end: { type: string, format: date-time }
        resources:
          $ref: "#/components/schemas/WorkOrder/properties/resources"

  responses:
    Patched:
      description: OK
      headers: { ETag: { schema: { type: string } } }
      content:
        application/json:
          schema: { $ref: "#/components/schemas/WorkOrder" }
    Problem400: { $ref: "#/components/responses/ProblemBase" }
    Problem401: { $ref: "#/components/responses/ProblemBase" }
    Problem403: { $ref: "#/components/responses/ProblemBase" }
    Problem404: { $ref: "#/components/responses/ProblemBase" }
    Problem409: { $ref: "#/components/responses/ProblemBase" }
    Problem422: { $ref: "#/components/responses/ProblemBase" }
    ProblemBase:
      description: Erro no formato RFC7807
      content:
        application/problem+json:
          schema:
            $ref: "../error-model-rfc7807.json"
```

---

## 13) `rest/examples/work-orders.http` — Exemplos (REST Client/Insomnia/Postman)

```http
### Listar OS
GET https://api.obraflow.example/api/v1/work-orders?limit=20&filter[status]=SCHEDULED,IN_PROGRESS
Authorization: Bearer {{token}}
x-tenant-id: acme

### Criar OS (idempotente)
POST https://api.obraflow.example/api/v1/work-orders
Authorization: Bearer {{token}}
x-tenant-id: acme
Idempotency-Key: wo-create-{{timestamp}}
Content-Type: application/json

{
  "title": "Alvenaria Bloco A - Pav. 2",
  "plannedWindow": { "start": "2025-09-22T07:00:00Z", "end": "2025-09-25T17:00:00Z" }
}
```

---

## 14) `graphql/schema.graphql` — Schema BFF (amostra)

```graphql
schema {
  query: Query
  mutation: Mutation
}

"""
Diretiva para marcar depreciação com razão clara e data alvo.
"""
directive @deprecatedReason(reason: String!, sunsetAt: String) on FIELD_DEFINITION | ENUM_VALUE

type Query {
  workOrders(
    after: String
    first: Int = 50
    status: [WorkOrderStatus!]
    siteId: ID
    sort: [SortInput!]
  ): WorkOrderConnection!

  workOrder(id: ID!): WorkOrder
}

type Mutation {
  createWorkOrder(input: WorkOrderCreateInput!): WorkOrder!
  patchWorkOrder(id: ID!, patch: JSON!): WorkOrder!
}

scalar JSON
scalar DateTime

enum WorkOrderStatus { SCHEDULED IN_PROGRESS BLOCKED DONE CANCELLED }

input SortInput { field: String!, direction: SortDirection! }
enum SortDirection { ASC DESC }

type WorkOrder {
  id: ID!
  title: String!
  status: WorkOrderStatus!
  wbsPath: String
  plannedWindow: Window!
  resources: Resources
  etag: String! # para If-Match/concorrência
}

type Window { start: DateTime!, end: DateTime! }
type Resources {
  crew: [Crew!] @deprecatedReason(reason: "Use field `teams`", sunsetAt: "2026-06-30")
  teams: [Team!]
  equipment: [Equipment!]
  materials: [MaterialItem!]
}
type Crew { skill: String!, qty: Int! }
type Team { role: String!, size: Int! }
type Equipment { type: String!, qty: Int! }
type MaterialItem { sku: String!, qty: String! }

type WorkOrderEdge { node: WorkOrder!, cursor: String! }
type WorkOrderConnection {
  edges: [WorkOrderEdge!]!
  pageInfo: PageInfo!
}
type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

input WorkOrderCreateInput {
  title: String!
  wbsPath: String
  plannedWindow: WindowInput!
  resources: JSON
}
input WindowInput { start: DateTime!, end: DateTime! }
```

---

## 15) `graphql/guidelines.md`

```markdown
# GraphQL Guidelines

- **Paginação**: Relay-style (edges/cursors).
- **Erros**: mapeados para `errors[]` padrão GraphQL + extensão `problem` (RFC7807-like).
- **Cache**: ETag em `etag` por recurso (usar `If-Match` no PATCH via header no BFF).
- **Segurança**: AutZ ABAC resolvida no BFF por diretivas custom (`@requiresRole`, `@siteScope`).
- **Depr**: usar `@deprecatedReason`.
- **N+1**: DataLoader por agregados.
```

---

## 16) `ci/contract-verify.sh` — Verificação de Contrato (CI)

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "🔍 API Contract Verification Starting..."

# 1. Spectral Linting
echo "📋 Linting OpenAPI with Spectral..."
npx -y @stoplight/spectral-cli lint docs/10-architecture/api-governance/rest/openapi.yml -r docs/10-architecture/api-governance/lint/spectral.yaml --fail-severity=error

# 2. RFC 7807 Validation
echo "📄 Validating RFC 7807 error responses..."
grep -q "application/problem+json" docs/10-architecture/api-governance/rest/openapi.yml || {
  echo "❌ RFC 7807 error responses not found"
  exit 1
}

# 3. GraphQL Schema Validation
echo "🔍 Validating GraphQL schema..."
npx -y graphql-schema-linter docs/10-architecture/api-governance/graphql/schema.graphql --config-file .graphql-schema-linter.yml

# 4. OpenAPI Schema Validation
echo "📊 Validating OpenAPI schema completeness..."
npx -y @apidevtools/swagger-parser validate docs/10-architecture/api-governance/rest/openapi.yml

# 5. Security Headers Check
echo "🔒 Checking security headers..."
grep -q "x-tenant-id" docs/10-architecture/api-governance/rest/openapi.yml || {
  echo "❌ Required security header x-tenant-id not found"
  exit 1
}

# 6. Versioning Check
echo "🏷️ Checking API versioning..."
grep -q "/api/v[0-9]" docs/10-architecture/api-governance/rest/openapi.yml || {
  echo "❌ API versioning not found in paths"
  exit 1
}

# 7. Rate Limiting Headers Check
echo "⏱️ Checking rate limiting headers..."
grep -q "RateLimit-Limit" docs/10-architecture/api-governance/rest/openapi.yml || {
  echo "❌ Rate limiting headers not found"
  exit 1
}

# 8. Idempotency Key Check
echo "🔄 Checking idempotency headers..."
grep -q "Idempotency-Key" docs/10-architecture/api-governance/rest/openapi.yml || {
  echo "❌ Idempotency-Key header not found"
  exit 1
}

# 9. ETag Headers Check
echo "🏷️ Checking ETag headers..."
grep -q "ETag" docs/10-architecture/api-governance/rest/openapi.yml || {
  echo "❌ ETag headers not found"
  exit 1
}

# 10. Pagination Check
echo "📄 Checking pagination structure..."
grep -q "page" docs/10-architecture/api-governance/rest/openapi.yml || {
  echo "❌ Pagination structure not found"
  exit 1
}

echo "✅ All API contract validations passed!"
```

---

## 17) `ci/prism-mock.docker-compose.yml` — Mock de API

```yaml
version: "3.9"
services:
  prism:
    image: stoplight/prism:4
    command: mock -h 0.0.0.0 -p 4010 --dynamic /mnt/openapi.yml
    volumes:
      - ../api-governance/rest/openapi.yml:/mnt/openapi.yml:ro
    ports:
      - "4010:4010"
    environment:
      - PRISM_DYNAMIC=true
      - PRISM_VERBOSE=true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4010/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped

  # Schema Registry para validação
  schema-registry:
    image: confluentinc/cp-schema-registry:7.4.0
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka:9092
      SCHEMA_REGISTRY_LISTENERS: http://0.0.0.0:8081
    ports:
      - "8081:8081"
    depends_on:
      - kafka
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/subjects"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Kafka para testes de eventos
  kafka:
    image: confluentinc/cp-kafka:7.4.0
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: true
    ports:
      - "9092:9092"
    depends_on:
      - zookeeper
    healthcheck:
      test: ["CMD", "kafka-broker-api-versions", "--bootstrap-server", "localhost:9092"]
      interval: 30s
      timeout: 10s
      retries: 3

  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "2181"]
      interval: 30s
      timeout: 10s
      retries: 3
```

---

## Amarrações (C4/UX/NFR)

* **BFF** aplica este guia, expondo **contratos consistentes** (latência p95, ETag, Idempotency-Key, 429).
* **UX** utiliza paginação cursor, sincronização condicional e mensagens de erro padronizadas (RFC 7807).
* **NFR/SLO**: as regras de latência/erro (Manifesto 1) são alimentadas pelas métricas RED por **rota**; **observabilidade** (Manifesto 4) usa `correlation_id`/`trace_id`/`tenant_id`.
* **Segurança & LGPD** (Manifesto 3): escopos por tenant/obra, PII minimizada, erros sem vazar detalhes, rate-limit por tenant.

---

Posso seguir para o **Manifesto 6 — *Infra/GitOps Baseline (Helm/Kustomize, ArgoCD, Istio/Linkerd, External Secrets, Policies)***, ou prefere ajustar algum detalhe deste pacote de API primeiro?
