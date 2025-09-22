# Personas e Jornadas do Usuário

## Personas Principais

### 1. Engenheiro Residente
**Perfil**: Profissional técnico responsável pelo planejamento e execução da obra
- **Responsabilidades**: Planejar cronogramas, validar medições, aprovar compras, acompanhar KPIs
- **Necessidades**: Visão executiva, controle de qualidade, tomada de decisões baseada em dados
- **Frustrações**: Falta de visibilidade em tempo real, processos manuais, dificuldade de rastreamento

### 2. Mestre/Encarregado
**Perfil**: Supervisor de campo responsável pela execução direta das atividades
- **Responsabilidades**: Receber OS, apontar produção, executar checklists, gerenciar equipe
- **Necessidades**: Interface mobile simples, operação offline, checklists guiados
- **Frustrações**: Conectividade intermitente, interfaces complexas, falta de orientação clara

### 3. Analista de Suprimentos
**Perfil**: Profissional responsável pela gestão de materiais e equipamentos
- **Responsabilidades**: Requisições, cotações, ordens de compra, recebimento em canteiro
- **Necessidades**: Visão de estoque, previsão de demanda, integração com fornecedores
- **Frustrações**: Falta de visibilidade de consumo, atrasos na entrega, processos manuais

### 4. Fiscal do Contratante
**Perfil**: Representante do contratante responsável pela fiscalização e aceite
- **Responsabilidades**: Fiscalizar execução, validar medições, aprovar serviços
- **Necessidades**: Evidências claras, trilha de auditoria, interface de aprovação
- **Frustrações**: Falta de evidências, processos burocráticos, dificuldade de rastreamento

### 5. Especialista em Qualidade/Segurança
**Perfil**: Profissional responsável por inspeções e conformidade
- **Responsabilidades**: Inspeções, NCs, APR, incidentes, relatórios
- **Necessidades**: Checklists padronizados, evidências fotográficas, relatórios automáticos
- **Frustrações**: Processos inconsistentes, falta de padronização, relatórios manuais

## Jornadas Críticas

### 1. Planejamento → Execução → Medição
**Objetivo**: Fluxo completo de planejamento até faturamento

**Etapas**:
1. **Planejamento** (Engenheiro)
   - Criar EAP/WBS
   - Definir cronograma e dependências
   - Alocar recursos (equipe, equipamentos, materiais)
   - Publicar plano aprovado

2. **Geração de OS** (Sistema)
   - Criar ordens de serviço baseadas no plano
   - Atribuir responsáveis
   - Definir janelas de execução
   - Notificar equipes

3. **Execução** (Mestre/Encarregado)
   - Receber OS no mobile
   - Executar checklists de segurança
   - Apontar produção em tempo real
   - Anexar evidências fotográficas

4. **Medição** (Sistema + Fiscal)
   - Consolidar apontamentos
   - Aplicar regras de medição
   - Solicitar aprovação do fiscal
   - Gerar relatório de medição

**Pontos de Dor**:
- Falta de sincronização entre planejamento e execução
- Medições manuais propensas a erros
- Dificuldade de rastreamento de evidências

### 2. Requisição → Compra → Recebimento
**Objetivo**: Garantir disponibilidade de materiais e equipamentos

**Etapas**:
1. **Requisição** (Mestre/Encarregado)
   - Identificar necessidade de material
   - Criar requisição no mobile
   - Especificar urgência e local de entrega

2. **Aprovação** (Engenheiro)
   - Revisar requisição
   - Aprovar ou solicitar ajustes
   - Definir orçamento disponível

3. **Cotação** (Suprimentos)
   - Enviar RFQ para fornecedores
   - Comparar propostas
   - Selecionar melhor oferta

4. **Compra** (Suprimentos)
   - Emitir ordem de compra
   - Acompanhar entrega
   - Confirmar recebimento

5. **Recebimento** (Canteiro)
   - Escanear QR code do material
   - Verificar quantidade e qualidade
   - Registrar no sistema

**Pontos de Dor**:
- Falta de visibilidade de estoque
- Atrasos na aprovação
- Dificuldade de rastreamento de entregas

### 3. Inspeção → NC → Correção
**Objetivo**: Garantir qualidade e conformidade

**Etapas**:
1. **Inspeção** (Qualidade/Segurança)
   - Executar checklist de inspeção
   - Identificar não-conformidades
   - Documentar evidências

2. **Abertura de NC** (Sistema)
   - Registrar não-conformidade
   - Classificar severidade
   - Atribuir responsável pela correção

3. **Ação Corretiva** (Responsável)
   - Implementar correção
   - Documentar evidências
   - Solicitar re-inspeção

4. **Fechamento** (Qualidade/Segurança)
   - Verificar correção
   - Aprovar fechamento
   - Atualizar relatórios

**Pontos de Dor**:
- Processos inconsistentes
- Falta de padronização
- Dificuldade de rastreamento

## Cenários de Uso Prioritários

### Mobile (Campo)
1. **Minhas OS do Dia**
   - Lista de OS atribuídas
   - Status e progresso
   - Ações rápidas (iniciar, pausar, finalizar)

2. **Apontamento de Produção**
   - Interface simples para quantidade
   - Upload de fotos com anotações
   - Geolocalização automática

3. **Checklist de Segurança**
   - Lista de verificação guiada
   - Assinatura digital
   - Evidências fotográficas

4. **Scanner QR/NFC**
   - Leitura de materiais e equipamentos
   - Check-in/check-out automático
   - Validação de conformidade

### Web (Escritório)
1. **Dashboard Executivo**
   - KPIs principais (SPI/CPI)
   - Status das obras
   - Alertas e notificações

2. **Planejamento (Gantt)**
   - Cronograma visual
   - Dependências e restrições
   - Simulação "what-if"

3. **Gestão de Recursos**
   - Alocação de equipes
   - Reserva de equipamentos
   - Otimização automática

4. **Relatórios e Analytics**
   - Medições e faturamento
   - Análise de produtividade
   - Previsões e tendências

## Requisitos de UX/UI

### Mobile
- **Offline-first**: Funcionamento sem conectividade
- **One-thumb operation**: Interface otimizada para uso com uma mão
- **Quick actions**: Ações frequentes acessíveis rapidamente
- **Visual feedback**: Confirmações claras de ações

### Web
- **Responsive**: Adaptação a diferentes tamanhos de tela
- **Keyboard shortcuts**: Atalhos para usuários experientes
- **Bulk operations**: Ações em lote para eficiência
- **Real-time updates**: Atualizações automáticas via WebSocket

### Acessibilidade
- **WCAG 2.2 AA**: Conformidade com padrões de acessibilidade
- **High contrast**: Suporte a modo de alto contraste
- **Screen readers**: Compatibilidade com leitores de tela
- **Keyboard navigation**: Navegação completa por teclado

## Métricas de Sucesso

### Adoção
- **Daily Active Users (DAU)**: Usuários ativos diariamente
- **Feature adoption**: Taxa de adoção de funcionalidades
- **Session duration**: Tempo médio de sessão

### Eficiência
- **Time to complete task**: Tempo para completar tarefas críticas
- **Error rate**: Taxa de erro em formulários e processos
- **Support tickets**: Redução de tickets de suporte

### Satisfação
- **User satisfaction score**: Pontuação de satisfação do usuário
- **Net Promoter Score (NPS)**: Recomendação do produto
- **Feature request frequency**: Frequência de solicitações de melhorias

## Referências

- [Visão Geral do Sistema](01-system-overview.md) - Contexto e objetivos
- [Design UX/UI](../02-architecture/03-ux-ui-design.md) - Especificações de interface
- [Requisitos Funcionais](../03-requirements/01-functional-requirements.md) - Detalhamento técnico
