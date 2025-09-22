# ObraFlow — Sistema Cloud Native de Gerenciamento de Processos para Construção Civil (Mobile + Web + Backend Distribuído + IA)

A seguir apresento uma proposta arquitetural completa — orientada a domínio, cloud native e “AI-ready” — para planejar, distribuir, alocar, rastrear, mobilizar, adquirir, reservar e delegar atividades em obras. O escopo considera múltiplos perfis (engenheiros, mestres, encarregados, suprimentos, segurança, qualidade, financeiro e fornecedores), multi-tenant, operação em campo (offline-first) e integração com IoT/BIM.

---

## 1) Visão & Objetivos

**Visão:** um ecossistema de orquestração operacional de obras, centrado em processos, dados e eventos, assistido por IA, que reduz atrasos, melhora a acurácia de medições/planejamento e otimiza uso de recursos (pessoas, equipamentos e materiais).

**Objetivos estratégicos (MBA):**

* **Eficiência operacional:** reduzir lead time de mobilização e setup de frentes em ≥25%.
* **Confiabilidade do cronograma:** elevar previsibilidade (SPI/CPI) e confiabilidade de entregas com SLOs por frente de serviço.
* **Qualidade e segurança:** diminuir NCs (não-conformidades) e incidentes; rastreabilidade ponta-a-ponta.
* **FinOps:** visibilidade de custo por centro (obra, trecho, equipe), com otimização de alocação e compras.
* **Data & IA:** criar vantagem analítica (previsões, recomendações e automações) com governança.

---

## 2) Personas e Casos de Uso Essenciais

**Personas:** Engenheiro residente, Mestre/Encarregado, Planejamento, Suprimentos, Qualidade/Segurança, Topografia, Frota, Financeiro, Fornecedor, Fiscal do Contratante.

**Casos de uso (amostra):**

* **Planejamento & Sequenciamento:** EAP/WBS, pacotes de trabalho, janelas, restrições (clima, disponibilidade, frentes), curva S, cronograma físico-financeiro.
* **Distribuição & Delegação:** ordens de serviço (OS) geradas do plano; checklists; procedimentos; anexos multimídia; assinaturas digitais.
* **Alocação & Reserva:** times, equipamentos, materiais; conflito de recursos; reserva/compra/locação; janela logística.
* **Mobilização & Rastreio:** geofence, QR/NFC, BLE beacons; status por frente; diário de obra; apontamento de produção.
* **Aquisição & Suprimentos:** requisições, cotação/OC, SLA fornecedor, lead time, compliance fiscal.
* **Medições & Qualidade:** medições por item de serviço, fotos com anotações; NCs; RDO digital; aceite do fiscal.
* **Segurança:** APR/PGR, checklists, EPI, incidentes, inspeções.
* **Analytics & IA:** recomendações de alocação; detecção de risco de atraso; visão computacional para progresso e segurança; copiloto de obra.

---

## 3) Domínios e Bounded Contexts (DDD)

* **Planning**: EAP/WBS, cronograma, restrições, curva S.
* **Work-Management**: OS/ordens, tarefas, delegação, apontamentos.
* **Resource-Orchestration**: times, habilidades, equipamentos, janelas; otimização de alocação.
* **Procurement & Inventory**: requisições, cotações, ordens de compra, recebimento, estoque em canteiro.
* **Field-Ops**: mobilização, rastreio (GPS/QR/NFC/BLE), diário, fotos/vídeos.
* **Quality & Safety**: inspeções, NCs, APR, incidentes.
* **Measurement & Billing**: critérios, medições, curvas, aceite, faturamento.
* **Identity & Access (IAM)**: multi-tenant, RBAC/ABAC, segregação.
* **Observability & Audit**: logs/traces/métricas, trilha de auditoria.
* **Data & AI Platform**: lakehouse, features, MLOps, RAG, orquestração de agentes.

---

## 4) Arquitetura Macro (Cloud Native)

* **Frontends:**

  * **Mobile** (Android/iOS) **offline-first** (SQLite/replicação + sync conflituoso resolvido por CRDT/merge rules), captura multimídia, voz-para-texto, geofence.
  * **Web SPA** (Next.js 14 app router) para cockpit, painéis e cadastros.
  * **BFF** (NestJS): consolida contratos, auth, rate-limit, cache (Redis), anti-corrupção.
* **Backends (microserviços):** Go (Echo/Fx) para path críticos de concorrência + Node/Nest para serviços coordenadores/catálogos.

  * Comunicação interna **gRPC** e **eventos** (Kafka/Pulsar).
  * **CQRS + Event Sourcing** onde há necessidade de trilha imutável (OS, medições, alocações), com **Outbox** e **Sagas**.
* **Dados:**

  * **PostgreSQL** (OLTP, RLS por tenant), **TimescaleDB** (séries temporais), **MongoDB** (documentos, formulários dinâmicos), **S3/MinIO** (mídia), **OpenSearch** (busca/logs), **Redis** (cache/locks), **Vector DB** (RAG).
* **Observabilidade:** OpenTelemetry → **Tempo/Jaeger**, **Prometheus/Mimir**, **Loki**; dashboards Grafana.
* **Segurança:** OIDC (Keycloak/Cognito), mTLS intra-cluster, KMS, TDE, criptografia em trânsito/repouso, **LGPD** (minimização, consent, DSR, retenção).
* **Infra:** Kubernetes (EKS/GKE/AKS), **Helm** charts, Istio/Linkerd (mTLS/telemetria), ArgoCD/GitOps, Karpenter/Cluster-autoscaler.
* **FinOps:** cost allocation por namespace/tenant/workload, budgets/alerts.

---

## 5) Modelo de Interação (EIP) e Contratos

* **APIs externas:** REST/GraphQL (BFF), AsyncAPI para eventos.
* **Mensageria & Padrões:** Outbox, Sagas (orquestradas e coreografadas), Idempotent Consumer, Retry/Backoff/Dead-letter, Circuit Breaker, Bulkhead.
* **Eventos nucleares (exemplos):**

  * `WorkOrderCreated`, `WorkOrderScheduled`, `ResourceReserved`, `ReservationExpired`,
  * `MaterialRequisitionSubmitted`, `PurchaseOrderApproved`, `GoodsReceivedAtSite`,
  * `CrewCheckedIn`, `AssetScannedAtLocation`, `ProductionReported`,
  * `QualityInspectionFailed`, `NonConformanceOpened`, `IncidentReported`,
  * `MeasurementApproved`, `InvoiceIssued`,
  * **IA:** `AIAllocationSuggestionEmitted`, `RiskOfDelayDetected`, `CVHazardDetected`.

---

## 6) Fluxos Críticos (Sagas)

### 6.1 Alocação de Recurso para OS

1. `WorkOrderCreated` → Orquestrador verifica janelas e restrições.
2. Solicita **reserva** de equipe (skills) e equipamento (capacidade).
3. Se conflito: **IA** roda **CP-SAT/heurística** e emite `AIAllocationSuggestionEmitted`.
4. Sucesso → `ResourceReserved` (com TTL); falha → compensação (liberar reservas, replanejar).

### 6.2 Requisição → Compra → Entrega em Canteiro

1. `MaterialRequisitionSubmitted` (Field-Ops) → Procurement avalia estoque (projeção) e lead time.
2. Cotação e `PurchaseOrderApproved`.
3. Tracking logística; chegada dispara `GoodsReceivedAtSite` + atualização de projeções de estoque/curva S.

### 6.3 Medição & Faturamento

1. Apontamentos de produção geram `WorkProgressUpdated`.
2. Regras de medição (catálogo de serviços) calculam parcelas; inspeção de qualidade (`QualityInspectionPassed`).
3. `MeasurementApproved` → faturamento, integração ERP.

---

## 7) Capabilities de IA (alinhado às tendências)

* **Otimização de Alocação**: modelagem de restrições (turnos, skills, janelas, logística, clima) via **OR-Tools CP-SAT** + heurísticas; simulação de cenários “what-if”.
* **Previsão de Atrasos**: modelos de séries temporais/gradient boosting; features de clima, produtividade, absenteísmo, suprimentos.
* **Copiloto de Obra (multimodal):** chat contextual com RAG (normas, cadernos, procedimentos, OS, histórico de não-conformidades), **fotos/vídeos** para análise de progresso e segurança (detecção de EPI, áreas de risco).
* **NLP/Formulários Inteligentes:** transcrição (STT) de apontamentos/diário; extração de entidades de notas fiscais/documentos; sumarização de inspeções.
* **Recomendação de Compras**: reorder point dinâmico; sugestão de fornecedores com base em SLA/preço/qualidade.
* **MLOps & Governança:** MLFlow/Kedro/Vertex/SageMaker; champion-challenger; drift, **telemetria de qualidade de modelo**; guardrails (validadores, PII scrubbing, policy-as-code).

---

## 8) Multi-Tenancy, Segurança e Compliance

* **Isolamento:** por **schema** (Postgres) com **RLS** por tenant + namespaces K8s por cliente ou segmento.
* **RBAC/ABAC:** papéis (engenheiro, mestre, suprimentos, auditor) e políticas por obra/frente.
* **Auditoria & LGPD:** audit log imutável (ES/ES-like), consent, retenção por tipo de dado, PII vault, data lineage.

---

## 9) Mobile Offline-First (Campo)

* **Sincronização confiável:** fila local + **conflict resolution** (CRDT/estratégias last-write-wins por campo e merge semântico por formulário).
* **Recursos de campo:** checklists guiados, anexos, anotações em fotos, leitura QR/NFC, **check-in por geofence**, assinatura digital, **SSE**/WebSocket para atualizações.
* **Operação com rede intermitente:** compressão, diffs, retry/backoff.

---

## 10) Dados & Analytics

* **Lakehouse:** Bronze (raw: IoT, app, ERP), Silver (limpo), Gold (métricas de negócio).
* **Métricas (KPIs):** SPI/CPI, % avanço físico vs planejado, utilização de recursos, lead time de mobilização, OTIF de fornecedores, taxa de NC, TRIF, OEE de equipamentos.
* **Dashboards:** painéis por obra, frente, disciplina; “Executive View” e “Daily Huddles”.

---

## 11) Integrações Externas

* **ERP/Financeiro**, **BIM/IFC**, **Clima**, **Identity corporativo**, **fornecedores (EDI/portal)**, **IoT** (rastreador, medidores), **Drones** (upload de ortomosaicos).
* **Gateways de integração:** adapters anti-corrupção, **spec-driven** (OpenAPI/AsyncAPI), testes de contrato.

---

## 12) Observabilidade, SRE e Confiabilidade

* **Tracing** distribuído, **logs estruturados** (correlation/causation id), **métricas RED/USE**.
* **SLOs** por domínio (ex.: *latência p95 alocação < 300ms*; *sincronização móvel < 60s*).
* **Error Budgets & Playbooks:** runbooks, automação de rollback/feature-flags.

---

## 13) Roadmap por Fases (90–180 dias)

**Fase 0 — Fundacional (2–4 semanas):**
K8s + GitOps (ArgoCD), IAM (OIDC), Observabilidade (OTel+Grafana Stack), BFF + Portal web, esqueleto de 3 domínios (Planning, Work-Management, Resource).

**Fase 1 — MVP Campo (4–6 semanas):**
Mobile offline-first (OS, checklists, fotos), OS → Alocação simples → Apontamento → Medição básica; integrações clima.

**Fase 2 — Suprimentos & Estoque (4–6 semanas):**
Requisições, cotações, OC, recebimento; catálogo de serviços/itens; curva S inicial, dashboards.

**Fase 3 — IA Núcleo (4–8 semanas):**
Otimização de alocação (CP-SAT), risco de atraso, copiloto RAG (procedimentos + histórico de OS/NC).

**Fase 4 — Qualidade & Segurança (4–6 semanas):**
Inspeções, NCs, APR, visão computacional (EPI), relatórios executivos.

**Fase 5 — Escala & FinOps (4–8 semanas):**
Multi-tenant avançado, multi-região, custos/showback, automações de compliance.

---

## 14) Modelo de Dados (amostra) & Eventos

**WorkOrder (projeção de leitura):**

```json
{
  "id": "WO-2025-000123",
  "tenantId": "acme",
  "siteId": "obra-sp-01",
  "wbsPath": "1.2.3",
  "title": "Alvenaria Bloco A - Pavimento 2",
  "plannedWindow": {"start":"2025-09-22T07:00Z","end":"2025-09-25T17:00Z"},
  "status": "SCHEDULED",
  "resources": {
    "crew": [{"skill":"alvenaria","qty":6}],
    "equipment": [{"type":"betoneira","qty":1}],
    "materials": [{"sku":"bloco-14","qty":"5000 un"}]
  },
  "kpis": {"plannedQty":"450 m2","earnedValue":12000,"progressPct":35.5}
}
```

**Evento `ResourceReserved`:**

```json
{
  "eventId":"evt-7f3c",
  "type":"ResourceReserved",
  "occurredAt":"2025-09-21T12:10:00Z",
  "tenantId":"acme",
  "woId":"WO-2025-000123",
  "reservations":[
    {"resourceType":"crew","skill":"alvenaria","qty":6,"from":"2025-09-22T07:00Z","to":"2025-09-25T17:00Z"},
    {"resourceType":"equipment","type":"betoneira","qty":1,"from":"2025-09-22T07:00Z","to":"2025-09-25T17:00Z"}
  ],
  "ttlHours":24
}
```

---

## 15) Stack Sugerida (exemplar)

* **Front:** Next.js 14 (Web), React Native/Expo (Mobile), PrimeReact/PrimeFlex, Mapas (MapLibre), WebRTC p/ vídeo em inspeções.
* **BFF:** NestJS (REST/GraphQL, Zod/joi, caching, rate limit, federation).
* **Services:**

  * Go (Echo/Fx) → Resource Orchestration, Measurement, Field Telemetry;
  * Node/Nest → Planning, Work-Management, Procurement, Quality/Safety.
* **Mensageria:** Kafka + Schema Registry; AsyncAPI.
* **DBs:** Postgres/Timescale, Mongo, Redis, MinIO/S3, OpenSearch, **Vector DB** (pgvector/Weaviate).
* **IA:** OR-Tools (alocação), pipelines MLFlow/Kedro; LLM gateway com guardrails (regras, redatores, PII scrub).

---

## 16) Governança & Gestão

* **Spec-Driven Development:** OpenAPI/AsyncAPI “single source of truth”.
* **Backlog inicial (épicos):** Planejamento, OS & Delegação, Alocação & Reserva, Suprimentos & Estoque, Medição & Curva S, Qualidade & Segurança, Mobile Offline, Observabilidade & SRE, IA (Alocação/Risco/Copiloto).
* **KPIs executivos:** prazo, custo, qualidade, segurança, produtividade, utilização de recursos.

---

## 17) Benefícios de Negócio

* **Redução de custos** (compra e logística assertivas), **redução de atrasos**, **melhor controle de qualidade/segurança**, **menor esforço de reconciliação** (medições e faturamento), **decisões guiadas por dados** e **padronização corporativa** entre obras.

---

Se quiser, prossigo com **(a)** um **C4-PlantUML** de Contexto/Contêiner/Componentes adaptado ao seu cenário, **(b)** os **esquemas AsyncAPI** dos eventos-chave e **(c)** um **MVP técnico** com skeleton de serviços (NestJS + Go), inclusive **Sagas/Outbox** e **pipelines de IA** (alocação) para você colar no repositório.
