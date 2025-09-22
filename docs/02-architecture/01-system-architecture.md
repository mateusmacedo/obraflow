# Arquitetura do Sistema ObraFlow

## Visão Geral

O ObraFlow é um sistema cloud native de gerenciamento de processos para construção civil, projetado como um **monorepo multilíngue** (TypeScript + Go) seguindo padrões de **Domain-Driven Design (DDD)**, **Clean Architecture** e **CQRS+EDA**.

## Stack Tecnológica

- **Frontend**: Next.js 14 (App Router) + React Native/Expo (mobile offline-first)
- **Backend**: NestJS (BFF) + Go Echo + Fx + Watermill (microserviços)
- **Observabilidade**: OpenTelemetry → Tempo/Jaeger + Prometheus + Loki + Grafana
- **Dados**: PostgreSQL (RLS multi-tenant) + MongoDB + Redis + TimescaleDB
- **CI/CD**: GitHub Actions + Nx + pnpm + Changesets

## Princípios Arquiteturais

### 1. Domain-Driven Design (DDD)
- **Bounded Contexts** claramente definidos
- **Aggregates** com invariantes de negócio
- **Domain Events** para comunicação entre contextos
- **Ubiquitous Language** consistente

### 2. Clean Architecture
- **Separação de responsabilidades** por camadas
- **Dependency Inversion** com interfaces
- **Testabilidade** em todas as camadas
- **Independência** de frameworks externos

### 3. CQRS + Event Sourcing
- **Comandos** para alterações de estado
- **Queries** para leitura otimizada
- **Event Store** para trilha de auditoria
- **Projections** para views de leitura

### 4. Event-Driven Architecture
- **Event Bus** (Kafka) para comunicação assíncrona
- **Sagas** para coordenação de processos
- **Outbox Pattern** para consistência eventual
- **Idempotência** para resiliência

## Domínios e Bounded Contexts

### Core Domains
- **Planning**: EAP/WBS, cronograma, restrições, curva S
- **Work-Management**: OS/ordens, tarefas, delegação, apontamentos
- **Resource-Orchestration**: times, habilidades, equipamentos, janelas
- **Measurement & Billing**: critérios, medições, curvas, aceite

### Supporting Domains
- **Procurement & Inventory**: requisições, cotações, ordens de compra
- **Quality & Safety**: inspeções, NCs, APR, incidentes
- **Field-Ops**: mobilização, rastreio, diário, fotos/vídeos

### Generic Domains
- **Identity & Access (IAM)**: multi-tenant, RBAC/ABAC
- **Observability & Audit**: logs/traces/métricas
- **Data & AI Platform**: lakehouse, features, MLOps

## Padrões de Integração

### APIs Externas
- **REST/GraphQL** (BFF) para frontend
- **gRPC** para comunicação interna
- **AsyncAPI** para eventos
- **OpenAPI** para contratos

### Mensageria
- **Kafka** como event bus principal
- **Outbox Pattern** para consistência
- **Sagas** (orquestradas e coreografadas)
- **Circuit Breaker** e **Retry/Backoff**

### Dados
- **PostgreSQL** para dados transacionais (RLS multi-tenant)
- **MongoDB** para documentos e formulários dinâmicos
- **TimescaleDB** para séries temporais
- **Redis** para cache e locks
- **S3/MinIO** para mídia e objetos

## Multi-Tenancy

### Isolamento
- **Schema** por tenant no PostgreSQL
- **RLS** (Row Level Security) por tenant/site
- **Namespaces** Kubernetes por cliente
- **Criptografia** em trânsito e repouso

### Segurança
- **OIDC/OAuth2** para autenticação
- **RBAC/ABAC** para autorização
- **mTLS** intra-cluster
- **Audit logs** imutáveis

## Observabilidade

### Telemetria
- **OpenTelemetry** para traces distribuídos
- **Prometheus** para métricas (RED/USE)
- **Loki** para logs estruturados
- **Grafana** para dashboards

### SLOs
- **Latência p95**: <300ms (API), <500ms (mobile sync)
- **Disponibilidade**: 99.9% (core), 99.5% (mobile sync)
- **Throughput**: >1000 RPS por tenant
- **Error Rate**: <0.1% (5xx errors)

## Mobile Offline-First

### Sincronização
- **SQLite** local com replicação
- **Conflict resolution** por CRDT/merge rules
- **Geofence** para check-in automático
- **Compressão** e **diffs** para eficiência

### Recursos de Campo
- **Checklists** guiados
- **Scanner** QR/NFC
- **Upload** multimídia offline
- **Assinatura** digital
- **Voice-to-text** para anotações

## Integrações Externas

### Sistemas Corporativos
- **ERP/Financeiro** para orçamentos e faturamento
- **BIM/IFC** para modelos 3D
- **Identity corporativo** para SSO
- **Fornecedores** via EDI/portal

### IoT e Sensores
- **Rastreadores** GPS
- **Beacons** BLE
- **Medidores** de produção
- **Drones** para ortomosaicos

## Capacidades de IA

### Otimização
- **OR-Tools CP-SAT** para alocação de recursos
- **Simulação** de cenários "what-if"
- **Previsão** de atrasos com séries temporais

### Assistência
- **RAG** para consultas contextuais
- **Visão computacional** para progresso e segurança
- **NLP** para formulários inteligentes
- **Copiloto** de obra multimodal

## Roadmap de Implementação

### Fase 0 — Fundacional (2-4 semanas)
- K8s + GitOps, IAM, Observabilidade
- BFF + Portal web, 3 domínios core

### Fase 1 — MVP Campo (4-6 semanas)
- Mobile offline-first, OS, checklists
- Alocação simples, medição básica

### Fase 2 — Suprimentos (4-6 semanas)
- Requisições, cotações, OC, recebimento
- Catálogo de serviços, curva S

### Fase 3 — IA Núcleo (4-8 semanas)
- Otimização de alocação, risco de atraso
- Copiloto RAG, recomendações

### Fase 4 — Qualidade & Segurança (4-6 semanas)
- Inspeções, NCs, APR, visão computacional

### Fase 5 — Escala & FinOps (4-8 semanas)
- Multi-tenant avançado, multi-região
- Custos/showback, automações

## Referências

- [Diagramas C4](02-c4-diagrams.md) - Visualização da arquitetura
- [Design UX/UI](03-ux-ui-design.md) - Interface e experiência do usuário
- [Requisitos NFR](../03-requirements/02-non-functional-requirements.md) - Requisitos não-funcionais
- [Catálogo de Eventos](../03-requirements/04-event-catalog.md) - Contratos de integração
