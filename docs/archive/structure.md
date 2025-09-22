## 📚 Bibliotecas e Recursos Comuns Cross-Platform

### 🔧 **Framework Core & DDD**
- **TypeScript**: `libs/ts/framework-core`
  - Result<T,E> (Either pattern)
  - DomainError
  - Event, Command, Query
  - UseCase
  - Ports/Adapters

- **Go**: `libs/go/pkg/core`
  - Result pattern equivalente
  - Domain errors
  - Event/Command contracts
  - Use case interfaces

### �� **Logging Estruturado**
- **TypeScript**: `libs/ts/logging-pino`
  - Pino logger
  - Redaction de dados sensíveis
  - TraceId binding
  - Structured logging

- **Go**: `libs/go/pkg/logging`
  - Zap logger wrappers
  - Níveis de log configuráveis
  - Campos padrão (traceId, service)
  - Structured logging

### �� **Observabilidade (OTel)**
- **TypeScript**: `libs/ts/otel-sdk`
  - OTel SDK Node/Browser
  - Auto-instrumentation
  - Tracer/Meter setup
  - Propagators

- **Go**: `libs/go/pkg/otel`
  - OTel SDK Go
  - Tracer/Meter providers
  - HTTP middleware (Echo)
  - Watermill middlewares

### 🔐 **Segurança & Autenticação**
- **TypeScript**: `libs/ts/security`
  - JWT (RS256)
  - RBAC decorators (Nest)
  - Guards e interceptors
  - Input validation (Zod)

- **Go**: `libs/go/pkg/security`
  - JWT validation
  - RBAC middleware
  - Input validation
  - Security headers

### 🌐 **HTTP Client**
- **TypeScript**: `libs/ts/http-client`
  - Fetch/Axios wrapper
  - Retry policies
  - Circuit breaker
  - Tracing integration

- **Go**: `libs/go/pkg/http`
  - HTTP client wrapper
  - Retry com backoff
  - Circuit breaker
  - Tracing middleware

### �� **Eventos & Mensageria**
- **TypeScript**: `libs/ts/events`
  - Event contracts
  - Publisher/Subscriber interfaces
  - Event sourcing helpers

- **Go**: `libs/go/pkg/events`
  - Watermill contracts
  - Message keying/headers
  - Publisher/Subscriber helpers

### �� **Cache & Persistência**
- **TypeScript**: `libs/ts/cache`
  - Redis adapter
  - Interface abstractions
  - Idempotência
  - Outbox pattern

- **Go**: `libs/go/pkg/cache`
  - Redis client wrapper
  - Repository interfaces
  - Idempotência
  - Outbox pattern

### 🧪 **Testes & Qualidade**
- **TypeScript**:
  - Jest/Vitest
  - Testing Library
  - Supertest (e2e)
  - Coverage gates

- **Go**:
  - Testing package
  - Testify
  - Race detector
  - Coverage gates

### �� **Retry & Resilience**
- **TypeScript**: `libs/ts/resilience`
  - Retry policies
  - Circuit breaker
  - Timeout handling
  - Bulkhead pattern

- **Go**: `libs/go/pkg/resilience`
  - Retry com backoff
  - Circuit breaker
  - Timeout context
  - Bulkhead pattern

### 📊 **Métricas & Health Checks**
- **TypeScript**: `libs/ts/health`
  - Health check endpoints
  - Metrics collection
  - Liveness/Readiness

- **Go**: `libs/go/pkg/health`
  - Health check handlers
  - Metrics exposition
  - Liveness/Readiness

### 🛠️ **Configuração**
- **TypeScript**: `libs/ts/config`
  - Environment validation
  - Schema validation (Zod)
  - Type-safe config

- **Go**: `libs/go/pkg/config`
  - Viper integration
  - Environment binding
  - Validation

### 🔧 **Utilitários**
- **TypeScript**: `libs/ts/utils`
  - Date/time helpers
  - String utilities
  - Validation helpers
  - Type guards

- **Go**: `libs/go/pkg/utils`
  - Time utilities
  - String helpers
  - Validation functions
  - Type assertions

## ��️ **Estrutura de Implementação Recomendada**

```
libs/
├─ ts/
│  ├─ framework-core/     # DDD patterns
│  ├─ logging-pino/       # Logging
│  ├─ otel-sdk/          # Observabilidade
│  ├─ security/          # Auth & RBAC
│  ├─ http-client/       # HTTP utilities
│  ├─ events/            # Event contracts
│  ├─ cache/             # Cache layer
│  ├─ resilience/        # Retry & circuit breaker
│  ├─ health/            # Health checks
│  ├─ config/            # Configuration
│  └─ utils/             # Utilities
└─ go/
   ├─ pkg/
   │  ├─ core/           # DDD patterns
   │  ├─ logging/        # Zap wrappers
   │  ├─ otel/           # OTel setup
   │  ├─ security/       # Auth & RBAC
   │  ├─ http/           # HTTP utilities
   │  ├─ events/         # Watermill contracts
   │  ├─ cache/          # Cache layer
   │  ├─ resilience/     # Retry & circuit breaker
   │  ├─ health/         # Health checks
   │  ├─ config/         # Configuration
   │  └─ utils/          # Utilities
   └─ internal/          # Shared internals
```

## 🎯 **Benefícios da Abordagem Cross-Platform**

1. **Consistência**: Mesmos padrões e contratos em ambas as linguagens
2. **Reutilização**: Lógica de negócio compartilhada
3. **Manutenibilidade**: Mudanças sincronizadas entre TS e Go
4. **Onboarding**: Desenvolvedores familiarizados com um lado podem facilmente trabalhar no outro
5. **Testes**: Estratégias de teste similares
6. **Observabilidade**: Traces e métricas consistentes entre serviços

Esta estrutura permite que você mantenha a mesma arquitetura e padrões em ambos os ecossistemas, facilitando a manutenção e evolução do monorepo multilíngue.