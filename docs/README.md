# 📚 ObraFlow - Documentação Técnica Organizada

Esta documentação foi reorganizada para facilitar a navegação e compreensão da arquitetura e operação do sistema ObraFlow.

## 🗂️ Estrutura da Documentação

### **00-context/** - Contexto e Visão Geral
- **[00-brazilian-construction-context.md](00-context/00-brazilian-construction-context.md)** - Contexto técnico da construção civil brasileira e instrumentos normativos
- **[01-obraflow-overview.md](00-context/01-obraflow-overview.md)** - Visão geral do sistema ObraFlow, arquitetura, objetivos e roadmap

### **02-architecture/** - Arquitetura e Design
- **[02-c4-diagrams.md](02-architecture/02-c4-diagrams.md)** - Diagramas C4 (Context, Container, Component, Deployment) em PlantUML
- **[03-ux-ui-design.md](02-architecture/03-ux-ui-design.md)** - Projeto UX/UI descritivo, princípios, personas e design system

### **04-requirements/** - Requisitos e Especificações
- **[04-nfr-slos-chaos.md](04-requirements/04-nfr-slos-chaos.md)** - NFR Charter, SLIs/SLOs, validação e experimentos de caos
- **[05-event-catalog-asyncapi.md](04-requirements/05-event-catalog-asyncapi.md)** - Catálogo de eventos AsyncAPI, nomenclatura, versionamento e contratos Kafka

### **06-security-privacy/** - Segurança e Privacidade
- **[06-threat-model-dpia.md](06-security-privacy/06-threat-model-dpia.md)** - Modelo de ameaças, DPIA (LGPD) e políticas de segurança
- **[15-platform-security-lgpd.md](06-security-privacy/15-platform-security-lgpd.md)** - Segurança avançada de plataforma, DLP, chaves, segredos e data residency

### **07-observability/** - Observabilidade e APIs
- **[07-observability-charter.md](07-observability/07-observability-charter.md)** - Charter de observabilidade (RED/USE), OTel Collector, dashboards e alertas
- **[08-api-governance.md](07-observability/08-api-governance.md)** - Governança de APIs (REST/OpenAPI & GraphQL), resiliência e contratos

### **09-infrastructure/** - Infraestrutura e Testes
- **[09-infra-gitops-baseline.md](09-infrastructure/09-infra-gitops-baseline.md)** - Baseline de infraestrutura GitOps (Helm, Kustomize, ArgoCD, Istio)
- **[10-test-strategy.md](09-infrastructure/10-test-strategy.md)** - Estratégia de testes (Pirâmide, CDC, E2E, Performance, Caos, Segurança)

### **11-operations/** - Operações e Gestão
- **[11-release-versioning.md](11-operations/11-release-versioning.md)** - Release, versionamento e gestão de mudanças (SemVer, Feature Flags, CAB)
- **[12-runbooks-incidents.md](11-operations/12-runbooks-incidents.md)** - Runbooks e gestão de incidentes (RACI, severidades, RCA, comunicação)
- **[13-dr-bcp.md](11-operations/13-dr-bcp.md)** - Disaster Recovery e Business Continuity Plan (RTO/RPO, backups, exercícios)

### **14-finops/** - Governança Financeira
- **[14-finops-cost-governance.md](14-finops/14-finops-cost-governance.md)** - FinOps e governança de custos (unit economics, orçamentos, otimização)

### **15-ai-ml/** - Inteligência Artificial
- **[15-ai-ml-ops.md](15-ai-ml/15-ai-ml-ops.md)** - AI/ML Ops para assistentes e otimização de recursos (RAG, recomendações, visão computacional)

### **16-data/** - Plataforma de Dados
- **[16-data-platform-mesh.md](16-data/16-data-platform-mesh.md)** - Data Platform e Data Mesh operacional (camadas, contratos, qualidade, catálogo)
- **[17-analytics-bi.md](16-data/17-analytics-bi.md)** - Analytics & BI (métricas, camada semântica, dashboards executivos)

### **18-compliance/** - Conformidade e Controles
- **[18-compliance-controls.md](18-compliance/18-compliance-controls.md)** - Compliance & Controles (ISO 27001, SOC 2, ANPD - evidências e automações)

## 🎯 Como Navegar

### **Para Arquitetos e Desenvolvedores:**
1. Comece com `00-context/` para entender o contexto
2. Revise `02-architecture/` para a visão técnica
3. Consulte `04-requirements/` para requisitos específicos
4. Use `07-observability/` para padrões de APIs e observabilidade

### **Para Operações e SRE:**
1. Foque em `09-infrastructure/` para infraestrutura
2. Use `11-operations/` para runbooks e procedimentos
3. Consulte `06-security-privacy/` para políticas de segurança
4. Revise `18-compliance/` para controles e conformidade

### **Para Product Owners e Gestores:**
1. Comece com `00-context/01-obraflow-overview.md`
2. Revise `02-architecture/03-ux-ui-design.md` para UX
3. Consulte `14-finops/` para governança financeira
4. Use `16-data/17-analytics-bi.md` para métricas e BI

### **Para Especialistas em Dados:**
1. Foque em `16-data/` para plataforma de dados
2. Consulte `15-ai-ml/` para capacidades de IA
3. Revise `06-security-privacy/` para privacidade e LGPD

## 🔗 Referências Cruzadas

Os manifestos são interconectados e fazem referências uns aos outros. Use os links internos para navegar entre documentos relacionados.

## 📝 Convenções

- **Números prefixos**: Organizam os documentos por ordem lógica de leitura
- **Nomes descritivos**: Facilitam a identificação do conteúdo
- **Agrupamento por domínio**: Documentos relacionados ficam próximos
- **Referências consistentes**: Links internos mantêm a navegação fluida

## 🚀 Próximos Passos

1. **Revisar** a estrutura e ajustar conforme necessário
2. **Atualizar** referências cruzadas entre documentos
3. **Criar** índices específicos por domínio se necessário
4. **Manter** a organização conforme novos documentos são adicionados
