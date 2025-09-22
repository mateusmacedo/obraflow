# 📚 ObraFlow - Documentação Técnica

Sistema cloud native de gerenciamento de processos para construção civil (mobile + web + backend distribuído + IA).

## 🗂️ Estrutura da Documentação


### **01-overview/** - Visão Geral e Contexto
- **[01-system-overview.md](01-overview/01-system-overview.md)** - Visão geral do sistema, objetivos e roadmap
- **[02-brazilian-construction-context.md](01-overview/02-brazilian-construction-context.md)** - Contexto técnico da construção civil brasileira
- **[03-personas-user-journeys.md](01-overview/03-personas-user-journeys.md)** - Personas, jornadas do usuário e casos de uso


### **02-architecture/** - Arquitetura e Design
- **[01-system-architecture.md](02-architecture/01-system-architecture.md)** - Arquitetura geral e decisões técnicas
- **[02-c4-diagrams.md](02-architecture/02-c4-diagrams.md)** - Diagramas C4 (Context, Container, Component, Deployment)
- **[03-ux-ui-design.md](02-architecture/03-ux-ui-design.md)** - Design system, componentes e padrões de UX/UI
- **[04-data-architecture.md](02-architecture/04-data-architecture.md)** - Arquitetura de dados e integrações


### **03-requirements/** - Requisitos e Especificações
- **[01-functional-requirements.md](03-requirements/01-functional-requirements.md)** - Requisitos funcionais por domínio
- **[02-non-functional-requirements.md](03-requirements/02-non-functional-requirements.md)** - NFR Charter, SLIs/SLOs e validação
- **[03-api-specifications.md](03-requirements/03-api-specifications.md)** - Especificações de APIs (OpenAPI, GraphQL)
- **[04-event-catalog.md](03-requirements/04-event-catalog.md)** - Catálogo de eventos AsyncAPI e contratos


### **04-security/** - Segurança e Privacidade
- **[01-security-overview.md](04-security/01-security-overview.md)** - Visão geral de segurança e compliance
- **[02-threat-model.md](04-security/02-threat-model.md)** - Modelo de ameaças e análise de riscos
- **[03-privacy-lgpd.md](04-security/03-privacy-lgpd.md)** - Privacidade, LGPD e DPIA
- **[04-security-policies.md](04-security/04-security-policies.md)** - Políticas e controles de segurança


### **05-observability/** - Observabilidade e Monitoramento
- **[01-observability-strategy.md](05-observability/01-observability-strategy.md)** - Estratégia de observabilidade (RED/USE)
- **[02-monitoring-dashboards.md](05-observability/02-monitoring-dashboards.md)** - Dashboards, alertas e métricas
- **[03-logging-tracing.md](05-observability/03-logging-tracing.md)** - Logging estruturado e distributed tracing


### **06-infrastructure/** - Infraestrutura e DevOps
- **[01-infrastructure-overview.md](06-infrastructure/01-infrastructure-overview.md)** - Visão geral da infraestrutura
- **[02-gitops-deployment.md](06-infrastructure/02-gitops-deployment.md)** - GitOps, CI/CD e deployment
- **[03-kubernetes-config.md](06-infrastructure/03-kubernetes-config.md)** - Configurações Kubernetes e Helm
- **[04-networking-security.md](06-infrastructure/04-networking-security.md)** - Rede, segurança e service mesh


### **07-testing/** - Estratégia de Testes
- **[01-testing-strategy.md](07-testing/01-testing-strategy.md)** - Estratégia geral de testes
- **[02-test-automation.md](07-testing/02-test-automation.md)** - Automação de testes e pipelines
- **[03-performance-testing.md](07-testing/03-performance-testing.md)** - Testes de performance e carga
- **[04-chaos-engineering.md](07-testing/04-chaos-engineering.md)** - Engenharia do caos e resiliência


### **08-operations/** - Operações e SRE
- **[01-operations-overview.md](08-operations/01-operations-overview.md)** - Visão geral das operações
- **[02-incident-management.md](08-operations/02-incident-management.md)** - Gestão de incidentes e runbooks
- **[03-release-management.md](08-operations/03-release-management.md)** - Gestão de releases e versionamento
- **[04-disaster-recovery.md](08-operations/04-disaster-recovery.md)** - Disaster recovery e business continuity


### **09-data-ai/** - Dados e Inteligência Artificial
- **[01-data-platform.md](09-data-ai/01-data-platform.md)** - Plataforma de dados e data mesh
- **[02-analytics-bi.md](09-data-ai/02-analytics-bi.md)** - Analytics, BI e métricas de negócio
- **[03-ai-ml-ops.md](09-data-ai/03-ai-ml-ops.md)** - AI/ML Ops e capacidades de IA
- **[04-data-governance.md](09-data-ai/04-data-governance.md)** - Governança de dados e qualidade


### **10-finops/** - Governança Financeira
- **[01-cost-governance.md](10-finops/01-cost-governance.md)** - Governança de custos e FinOps
- **[02-budget-planning.md](10-finops/02-budget-planning.md)** - Planejamento orçamentário e otimização


### **11-compliance/** - Conformidade e Auditoria
- **[01-compliance-overview.md](11-compliance/01-compliance-overview.md)** - Visão geral de compliance
- **[02-audit-controls.md](11-compliance/02-audit-controls.md)** - Controles de auditoria e evidências
- **[03-regulatory-requirements.md](11-compliance/03-regulatory-requirements.md)** - Requisitos regulatórios (ISO 27001, SOC 2, ANPD)

## 🎯 Guias por Público

### **Para Arquitetos e Desenvolvedores:**
1. **Início**: `01-overview/` → `02-architecture/` → `03-requirements/`
2. **Implementação**: `05-observability/` → `07-testing/` → `06-infrastructure/`

### **Para SRE e Operações:**
1. **Início**: `06-infrastructure/` → `08-operations/` → `05-observability/`
2. **Segurança**: `04-security/` → `11-compliance/`

### **Para Product Owners e Gestores:**
1. **Início**: `01-overview/` → `02-architecture/03-ux-ui-design.md`
2. **Métricas**: `09-data-ai/02-analytics-bi.md` → `10-finops/`

### **Para Especialistas em Dados:**
1. **Início**: `09-data-ai/` → `04-security/03-privacy-lgpd.md`

## 🔗 Navegação Rápida

- **🚀 Começar aqui**: [Visão Geral do Sistema](01-overview/01-system-overview.md)
- **🏗️ Arquitetura**: [Diagramas C4](02-architecture/02-c4-diagrams.md)
- **📋 Requisitos**: [NFR Charter](03-requirements/02-non-functional-requirements.md)
- **🔒 Segurança**: [Modelo de Ameaças](04-security/02-threat-model.md)
- **📊 Observabilidade**: [Estratégia de Observabilidade](05-observability/01-observability-strategy.md)
- **⚙️ Infraestrutura**: [GitOps e Deployment](06-infrastructure/02-gitops-deployment.md)
- **🧪 Testes**: [Estratégia de Testes](07-testing/01-testing-strategy.md)
- **🔧 Operações**: [Gestão de Incidentes](08-operations/02-incident-management.md)

## 📝 Convenções

- **Numeração sequencial**: 01, 02, 03... dentro de cada categoria
- **Nomes descritivos**: Fácil identificação do conteúdo
- **Agrupamento lógico**: Documentos relacionados próximos
- **Referências consistentes**: Links internos mantêm navegação fluida
- **Público-alvo claro**: Cada seção tem guia de navegação específico

## 🚀 Próximos Passos

1. **Revisar** a nova estrutura e ajustar conforme necessário
2. **Migrar** documentos existentes para nova organização
3. **Atualizar** todas as referências cruzadas
4. **Criar** índices específicos por domínio se necessário
5. **Manter** a organização conforme novos documentos são adicionados