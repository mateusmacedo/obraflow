# C4-PlantUML — ObraFlow (Contexto → Contêiner → Componente → Implantação)

Abaixo estão **4 diagramas C4 completos** (compatíveis com `C4-PlantUML`) para o sistema **ObraFlow**. Incluem estilos, tags, legendas e elementos essenciais: **DDD, CQRS/ES, Outbox/Sagas, Observabilidade, Multi-tenant, Segurança e IA**.

> **Como usar:** copie cada bloco `.puml` e renderize no seu PlantUML (local/CI) com acesso aos includes do repositório `C4-PlantUML`.

---

## 1) Contexto (C4: System Context)

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

title ObraFlow — Diagrama de Contexto (C4)

Person(engenheiro, "Engenheiro/Mestre/Encarregado", "Planeja, delega, aponta produção e valida medições.")
Person(suprimentos, "Analista de Suprimentos", "Conduz requisições, cotações e ordens de compra.")
Person(fiscal, "Fiscal do Contratante", "Fiscaliza, aceita serviços e auditorias.")
Person_Ext(fornecedor, "Fornecedor/Transportador", "Atende OCs, logística de materiais.")

System_Boundary(s, "Sistema ObraFlow") {
  System(obraf, "ObraFlow", "Plataforma cloud native de gestão de processos de obra (mobile/web, IA).")
}

System_Ext(idp, "Provedor de Identidade (OIDC)", "SSO/RBAC/ABAC corporativo.")
System_Ext(erp, "ERP/Financeiro", "Orçamentos, contas a pagar/receber, faturamento.")
System_Ext(clima, "API de Clima", "Previsão/alertas climáticos.")
System_Ext(bim, "BIM/IFC Repo", "Modelos e especificações técnicas.")
System_Ext(iot, "Plataforma IoT/Telemetria", "Tags, beacons, trackers, medições campo.")
System_Ext(msg, "Gateway Mensageria (E-mail/SMS/Push)", "Notificações externas.")
System_Ext(aihub, "AI Hub", "Modelos/serviços de IA e MLOps.")

Rel(engenheiro, obraf, "Usa (mobile/web) para planejar, delegar, apontar, medir, aprovar", "HTTPS")
Rel(suprimentos, obraf, "Registra requisições, cotações, OCs", "HTTPS")
Rel(fiscal, obraf, "Fiscaliza, aceita medições, auditorias", "HTTPS")
Rel(fornecedor, obraf, "Consulta OCs / janelas logísticas", "HTTPS")

Rel(obraf, idp, "Autenticação/Autorização (OIDC/OAuth2)", "HTTPS")
Rel(obraf, erp, "Integra orçamentos, OCs, faturas", "API/ETL")
Rel(obraf, clima, "Consulta previsão/alertas", "HTTPS")
Rel(obraf, bim, "Consulta/Anexa modelos IFC", "HTTPS")
Rel(obraf, iot, "Recebe telemetria / eventos de campo", "MQTT/HTTPS")
Rel(obraf, msg, "Envia e-mails/SMS/push", "HTTPS/SMTP")
Rel(obraf, aihub, "Serviços de IA (RAG, recomendações, visão computacional)", "HTTPS/gRPC")
@enduml
```

---

## 2) Contêineres (C4: Container)

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

title ObraFlow — Diagrama de Contêineres (C4)

Person(engenheiro, "Usuários de Campo/Escritório")

System_Boundary(obraf, "ObraFlow") {
  Container(web, "Web SPA", "Next.js 14", "Cockpit, painéis, cadastros.")
  Container(mobile, "Mobile App", "React Native/Expo", "Offline-first (sync, mídia, geofence).")
  Container(bff, "BFF/API Gateway", "NestJS", "REST/GraphQL, auth, caching, anti-corrupção.")

  ContainerQueue(kafka, "Event Bus", "Kafka", "Eventos, Sagas, Outbox.")
  Container(pg, "Relacional (OLTP)", "PostgreSQL (+RLS)", "Multi-tenant; dados transacionais.")
  Container(tsdb, "Time Series", "TimescaleDB", "Telemetria/produtividade/latência.")
  Container(mongo, "Documentos", "MongoDB", "Formulários dinâmicos, diários, anexos leves.")
  Container(search, "Busca/Logs", "OpenSearch", "Full-text, auditoria.")
  Container(vector, "Vector Store", "pgvector/Weaviate", "RAG e embeddings.")
  Container(redis, "Cache/Locks", "Redis", "Cache, rate limit, locks.")
  Container(obj, "Objetos", "S3/MinIO", "Mídia (fotos/vídeos/IFC).")

  Container(planning, "Planning Service", "Node/Nest", "EAP/WBS, janelas, curva S.")
  Container(work, "Work-Management Service", "Node/Nest", "OS, tarefas, apontamentos (CQRS/ES).")
  Container(resource, "Resource Orchestration Service", "Go/Echo", "Habilidades, janelas, otimização alocação.")
  Container(procure, "Procurement & Inventory Service", "Node/Nest", "Requisição, cotação, OC, estoque.")
  Container(qs, "Quality & Safety Service", "Node/Nest", "Inspeções, NCs, APR, incidentes.")
  Container(measure, "Measurement & Billing Service", "Go/Echo", "Medições, aceite, faturamento.")
  Container(iam, "IAM Adapter", "Node", "Integra OIDC/ABAC; multi-tenant.")
  Container(ai, "AI Orchestrator", "Node/Python", "RAG, OR-Tools, visão computacional.")
  Container(obs, "Observability Stack", "OTel/Tempo/Prometheus/Loki/Grafana", "Tracing, métricas, logs.")
}

Rel(engenheiro, web, "Usa", "HTTPS")
Rel(engenheiro, mobile, "Usa", "HTTPS")
Rel(web, bff, "API calls", "HTTPS")
Rel(mobile, bff, "API calls / Sync", "HTTPS/SSE")

Rel(bff, planning, "REST/gRPC", "mTLS")
Rel(bff, work, "REST/gRPC", "mTLS")
Rel(bff, resource, "REST/gRPC", "mTLS")
Rel(bff, procure, "REST/gRPC", "mTLS")
Rel(bff, qs, "REST/gRPC", "mTLS")
Rel(bff, measure, "REST/gRPC", "mTLS")
Rel(bff, iam, "OIDC/Token Introspection", "HTTPS")

Rel(work, kafka, "Publica/consome eventos (Outbox/Sagas)", "")
Rel(resource, kafka, "Coreografia/Orquestração", "")
Rel(procure, kafka, "Eventos de compra/estoque", "")
Rel(measure, kafka, "Eventos de medição/faturamento", "")
Rel(qs, kafka, "Eventos de qualidade/segurança", "")
Rel(ai, kafka, "Recomendações/alertas", "")

Rel(planning, pg, "CRUD plano/curva S", "")
Rel(work, pg, "Estado (CQRS/ES)", "")
Rel(work, obj, "Anexos", "")
Rel(resource, pg, "Capacidades/janelas", "")
Rel(procure, pg, "Requisições/OCs/estoque", "")
Rel(qs, mongo, "Formulários/inspeções", "")
Rel(measure, pg, "Medições/aceites", "")
Rel(ai, vector, "Embeddings", "")
Rel(obs, tsdb, "Séries temporais", "")
Rel(bff, redis, "Cache/token/locks", "")
Rel(bff, search, "Auditoria/busca", "")
@enduml
```

---

## 3) Componentes (C4: Component) — **Work-Management Service (CQRS/ES + Sagas/Outbox)**

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

title Work-Management Service — Diagrama de Componentes (C4)

Container_Boundary(work, "Work-Management Service (NestJS)") {
  Component(api, "HTTP/API Controllers", "NestJS Controllers", "REST/GraphQL, validação (Zod/Joi), DTOs.")
  Component(cmdBus, "Command Bus", "Mediator", "Dispatch de comandos.")
  Component(qryBus, "Query Bus", "Mediator", "Dispatch de queries.")
  Component(handlers, "Command/Query Handlers", "Application Layer", "CreateWorkOrder, AssignCrew, ReportProduction...")
  Component(saga, "Saga Orchestrator", "Process Manager", "Coordena fluxos (alocação, compras, medição).")
  Component(domain, "Domain Model", "Entities/Aggregates", "WorkOrder, Task, Assignment (invariantes).")
  Component(repo, "EventSourced Repository", "Infra", "Carrega/salva agregados no Event Store.")
  Component(eventStore, "Event Store", "Append-only", "WorkOrderCreated/Assigned/Completed...")
  Component(outbox, "Outbox Publisher", "Infra", "Publica eventos de integração (Kafka).")
  Component(projections, "Read Models/Projections", "NestJS + SQL", "Views para consultas rápidas (CQRS).")
  Component(authz, "Policy/Authorization", "ABAC/RBAC", "Regras por tenant/obra/frente.")
}

Rel(api, cmdBus, "Executa comandos")
Rel(api, qryBus, "Executa queries")
Rel(cmdBus, handlers, "Dispatch")
Rel(qryBus, projections, "Consulta")
Rel(handlers, domain, "Aplica regras de negócio")
Rel(handlers, repo, "Persistência (ES)")
Rel(repo, eventStore, "Append/Load events")
Rel(handlers, saga, "Emite eventos internos")
Rel(handlers, outbox, "Enfileira eventos integração", "")
Rel(projections, eventStore, "Projeta do ES (assíncrono)", "")
Rel(authz, api, "Enforcement (guards/interceptors)")

Component_Ext(kafka, "Kafka Topic(s)", "Mensageria", "Integração interdomínios")
Component_Ext(pg, "PostgreSQL (OLTP)", "DB", "Tabelas de leitura / snapshots")
Rel(outbox, kafka, "Publica eventos", "")
Rel(projections, pg, "Materializa read models")
@enduml
```

---

## 4) Implantação (C4: Deployment) — **Kubernetes (EKS) + Observabilidade + Segurança**

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Deployment.puml

title ObraFlow — Diagrama de Implantação (C4)

Deployment_Node(aws, "AWS Region", "Cloud") {
  Deployment_Node(eks, "Amazon EKS", "Kubernetes") {
    Deployment_Node(istio, "Service Mesh (Istio/Linkerd)", "mTLS/Telemetria") {
      Deployment_Node(ns_app, "Namespace: obraflow-app", "K8s") {
        Deployment_Node(ing, "Ingress/Gateway", "Istio/Traefik")
        Deployment_Node(webpod, "Pod: web-bff", "Next.js/NestJS")
        Deployment_Node(workpod, "work-mgmt", "NestJS")
        Deployment_Node(respod, "resource-orch", "Go/Echo")
        Deployment_Node(procurepod, "procurement", "NestJS")
        Deployment_Node(measpod, "measurement", "Go/Echo")
        Deployment_Node(qspod, "quality-safety", "NestJS")
        Deployment_Node(aipod, "ai-orchestrator", "Node/Python")
      }

      Deployment_Node(ns_data, "Namespace: obraflow-data", "K8s") {
        Deployment_Node(pg, "PostgreSQL", "StatefulSet")
        Deployment_Node(mongo, "MongoDB", "StatefulSet")
        Deployment_Node(tsdb, "TimescaleDB", "StatefulSet")
        Deployment_Node(search, "OpenSearch", "StatefulSet")
        Deployment_Node(redis, "Redis", "StatefulSet")
        Deployment_Node(obj, "MinIO/S3 Gateway", "Deployment")
        Deployment_Node(kafka, "Kafka", "Cluster")
      }

      Deployment_Node(ns_obs, "Namespace: observability", "K8s") {
        Deployment_Node(otel, "OpenTelemetry Collector", "Deployment")
        Deployment_Node(tempo, "Tempo/Jaeger", "Deployment")
        Deployment_Node(prom, "Prometheus/Mimir", "StatefulSet")
        Deployment_Node(loki, "Loki", "StatefulSet")
        Deployment_Node(graf, "Grafana", "Deployment")
      }
    }
  }
}

Rel(ing, webpod, "HTTP(S) ↔ mTLS", "")
Rel(webpod, workpod, "gRPC/HTTP ↔ mTLS", "")
Rel(webpod, respod, "gRPC/HTTP ↔ mTLS", "")
Rel(webpod, procurepod, "gRPC/HTTP ↔ mTLS", "")
Rel(webpod, measpod, "gRPC/HTTP ↔ mTLS", "")
Rel(webpod, qspod, "gRPC/HTTP ↔ mTLS", "")
Rel(webpod, aipod, "gRPC/HTTP ↔ mTLS", "")

Rel(workpod, kafka, "Eventos (SASL/SSL)", "")
Rel(respod, kafka, "Eventos (SASL/SSL)", "")
Rel(procurepod, kafka, "Eventos (SASL/SSL)", "")
Rel(measpod, kafka, "Eventos (SASL/SSL)", "")
Rel(qspod, kafka, "Eventos (SASL/SSL)", "")
Rel(aipod, kafka, "Eventos (SASL/SSL)", "")

Rel(workpod, pg, "SQL", "")
Rel(respod, pg, "SQL", "")
Rel(procurepod, pg, "SQL", "")
Rel(measpod, pg, "SQL", "")
Rel(qspod, mongo, "NoSQL", "")
Rel(aipod, search, "Search", "")

Rel(workpod, redis, "Cache", "")
Rel(respod, redis, "Cache", "")
Rel(procurepod, redis, "Cache", "")
Rel(measpod, redis, "Cache", "")
Rel(qspod, redis, "Cache", "")
Rel(aipod, redis, "Cache", "")

Rel(workpod, obj, "Objetos", "")
Rel(respod, obj, "Objetos", "")
Rel(procurepod, obj, "Objetos", "")
Rel(measpod, obj, "Objetos", "")
Rel(qspod, obj, "Objetos", "")
Rel(aipod, obj, "Objetos", "")

Rel(otel, workpod, "OTLP (traces/metrics/logs)")
Rel(otel, respod, "OTLP (traces/metrics/logs)")
Rel(otel, procurepod, "OTLP (traces/metrics/logs)")
Rel(otel, measpod, "OTLP (traces/metrics/logs)")
Rel(otel, qspod, "OTLP (traces/metrics/logs)")
Rel(otel, aipod, "OTLP (traces/metrics/logs)")

Rel(prom, workpod, "Scrape (metrics)")
Rel(prom, respod, "Scrape (metrics)")
Rel(prom, procurepod, "Scrape (metrics)")
Rel(prom, measpod, "Scrape (metrics)")
Rel(prom, qspod, "Scrape (metrics)")
Rel(prom, aipod, "Scrape (metrics)")

Rel(loki, workpod, "Logs (promtail/OTel)")
Rel(loki, respod, "Logs (promtail/OTel)")
Rel(loki, procurepod, "Logs (promtail/OTel)")
Rel(loki, measpod, "Logs (promtail/OTel)")
Rel(loki, qspod, "Logs (promtail/OTel)")
Rel(loki, aipod, "Logs (promtail/OTel)")

Rel(graf, prom, "Dashboards")
Rel(graf, tempo, "Dashboards (traces)")
Rel(graf, loki, "Dashboards (logs)")
@enduml
```

---

## Observações de Arquitetura

* **Multi-tenant**: reforçado por *namespaces* lógicos (domínios), **RLS** no Postgres e segmentação por obra/cliente.
* **Confiabilidade**: *Service Mesh* com **mTLS**, HPA/PodDisruptionBudgets, e **SLOs** por domínio.
* **CQRS/ES, Outbox & Sagas**: explícitos no componente de **Work-Management**; replicáveis a outros domínios.
* **IA**: orquestrador dedicado (RAG, otimização de alocação, visão computacional) + **Vector Store**.
* **Observabilidade**: telemetria unificada (traces/métricas/logs) e painéis operacionais/negócio.

---

Se quiser, eu **estendo** com:

1. **C4 Nível 3 (Componentes)** para **Resource Orchestration** e **Measurement**,
2. **C4-Dynamic** de uma **Saga** (Alocação → Compra → Medição),
3. **Infra C4 + IaC** (clusters multi-região, DR/backup, filas cross-region).
