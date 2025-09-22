# ObraFlow — Projeto Descritivo de UX/UI

*(Mobile + Web, Cloud-Native, IA-Ready, Multi-Tenant)*

Abaixo está uma proposta **end-to-end** de UX/UI que conecta **design do produto** com **system design** e **implementação**. O material cobre **arquitetura de informação**, **navegação**, **design system (tokens + componentes)**, **padrões de interação (offline-first, mapas, scanner, anotações)**, **telas prioritárias**, **acessibilidade**, **instrumentação/analytics**, **segurança/LGPD**, **entrega e handoff (Figma/Storybook/Cypress)** e **roadmap de versões**.

---

## 1) Princípios Norteadores

* **Job-to-be-done first**: fluxo otimizado para obra (menos cliques, “um polegar” no campo).
* **Offline-first & sync confiável**: operações locais com reconciliação (UI otimista + resolução de conflitos).
* **Progressive disclosure**: comece simples, revele profundidade quando necessário (ex.: inspeções detalhadas).
* **Observabilidade de UX**: eventos de produto, *error boundaries*, latência percebida, *session replay* opcional.
* **AI-assisted by default**: sugestões e *what-if* embutidos, não intrusivos (ex.: “Alocar equipe ideal”).
* **Acessibilidade & segurança**: WCAG 2.2 AA, mínimo de PII na tela, mascaramento/escopo por papel/obra.
* **Multi-tenant & *white-label***: temas por cliente (cores/logos), sem afetar legibilidade.

---

## 2) Personas & Jornadas-chave (resumo)

* **Engenheiro Residente**: programa, valida medições, aprova compras, acompanha KPIs.
* **Mestre/Encarregado**: recebe OS, aponta produção, checklist segurança/qualidade, fotos/anotações.
* **Suprimentos**: requisição → cotação → OC → recebimento em canteiro.
* **Qualidade/SSMA**: inspeções, NCs, APR, incidentes.
* **Fiscal do Contratante**: aceita serviços, valida medições e documenta evidências.

**Jornadas prioritárias:**

1. Planejar → Gerar OS → Alocar recursos → Executar → Medir → Faturar.
2. Requisitar material/equipamento → Comprar/Reservar → Receber → Usar.
3. Inspecionar qualidade/segurança → Abrir/Tratar NC → Fechar.

---

## 3) Arquitetura de Informação & Navegação

### 3.1 Estrutura Global

* **Web (cockpit)**: *Dashboard*, Planejamento (Gantt/Curva S), OS (Kanban/Tabela), Alocação, Suprimentos, Qualidade/Segurança, Medições, Relatórios, Admin (Tenants/RBAC), Configurações.
* **Mobile (campo)**: Minhas OS (Hoje/Semana), Checklists & Apontamentos, Scanner (QR/NFC), Mapas/Geofence, Diário de Obra, Inspeções/Incidentes, Upload multimídia, *SSE* de alterações.

### 3.2 Padrão de Rotas (Next.js App Router – exemplo)

```
/app
  /(auth)/login
  /(dashboard)
  /planning/gantt
  /work-orders/(list|kanban|calendar)/[filters]
  /work-orders/[woId]
  /allocation/timeline
  /procurement/(requisitions|rfq|po|receiving)
  /quality/(inspections|ncr|apr|incidents)
  /measurements/(runs|rules|approvals)
  /ai/copilot
  /admin/(tenants|users|roles|policies)
  /settings
```

### 3.3 Navegação & Descoberta

* **Global topbar**: troca de tenant/obra, busca global (Cmd/Ctrl-K), *quick actions*.
* **Sidebar contextual**: módulos por papel.
* **Breadcrumbs** e **tabs** para profundidade.

---

## 4) Design System (Tokens + Componentes)

### 4.1 Design Tokens (exemplo JSON)

```json
{
  "color": {
    "primary": {"50":"#E8F1FF","500":"#2563EB","700":"#1D4ED8"},
    "success": {"500":"#16A34A"},
    "warning": {"500":"#D97706"},
    "danger":  {"500":"#DC2626"},
    "surface": {"0":"#FFFFFF","50":"#F9FAFB","900":"#0B1220"},
    "text":    {"primary":"#0F172A","muted":"#475569","inverse":"#FFFFFF"}
  },
  "radius": {"sm":"6px","md":"10px","xl":"16px","pill":"9999px"},
  "shadow": {"sm":"0 1px 2px rgba(0,0,0,.06)","md":"0 4px 12px rgba(0,0,0,.10)"},
  "spacing": {"xs":"4px","sm":"8px","md":"12px","lg":"16px","xl":"24px"},
  "typography": {
    "fontFamily": {"base":"Inter, system-ui, sans-serif"},
    "scale": {"h1":32,"h2":24,"h3":20,"body":14,"caption":12}
  }
}
```

### 4.2 Componentes Base (lib compartilhada)

* **Input**, **Select (com *search*)**, **Date/Time**, **Number**, **Toggle**, **Textarea**, **Chip/Badge**, **Avatar**, **Tooltip/Popover**, **Modal/Drawer**, **Accordion**, **Tabs**, **Toast/Alert**, **DataTable** (colunas virtuais, export), **Upload** (fila + reprocessamento), **Stepper**, **Empty/Zero-state**, **Skeletons**.

### 4.3 Componentes Compostos (domínio)

* **WorkOrderCard** (status, progresso, janela, *chips* de recursos).
* **AllocationTimeline** (recursos vs tempo, conflitos, *drag-and-drop*).
* **ChecklistRunner** (fluxo passo-a-passo, leitura de normas).
* **InspectionForm** (evidências, assinatura, *co-piloto* de texto).
* **ProcurementBoard** (requisição→RFQ→OC→recebimento).
* **MeasurementRun** (itens, critérios, anexos, aceite).
* **MapSheet** (mapa, *geofence*, heatmap de produção/alertas).
* **MediaAnnotator** (desenho, *callouts*, OCR).

### 4.4 Estados Transversais

* **Carregando** (*skeletons*), **Vazio** (CTA claro), **Erro** (recuperável + ID de correlação), **Offline** (banner + fila de *sync*), **Sem permissão** (orientar solicitação).

### 4.5 Acessibilidade (WCAG 2.2 AA)

* Contraste mínimo, *focus ring* evidente, navegação por teclado, *skip links*, rótulos ARIA, tamanhos alvo ≥44px no mobile, legendas em mídia.

---

## 5) Padrões de Interação

* **Offline-first & UI Otimista**: ações críticas funcionam localmente; diffs e *retry/backoff* visíveis em “Sincronizações”.
* **Listas pesadas**: filtros salvos, *server-side* pagination, *column virtualization*, *bulk actions*.
* **Formulários**: validação progressiva, *autosave* local, *wizard* para fluxos longos.
* **Mapas & Geofence**: check-in/out por perímetro, camadas (OS ativas, restrições, risco).
* **Scanner**: QR/NFC em OS, materiais e equipamentos (atajos: “apontar produção”).
* **Mídia & Anotações**: fotos com marcação, *voice-to-text*, tags, compressão antes do envio.
* **Notificações**: *in-app* + push; painel de “atividade recente” com filtros.
* **IA embutida**: painel lateral “Sugestões” (alocação, riscos, *what-if*); explicabilidade simples (“por que sugeri?”).

---

## 6) Telas Prioritárias (Web & Mobile)

> Cada tela traz objetivo, dados-chave, ações primárias, componentes e estados.

### 6.1 Dashboard (Web)

* **Objetivo**: visão executiva (SPI/CPI, avanço físico vs planejado, gargalos, alertas IA).
* **Dados**: obras/locais, frentes ativas, clima, suprimentos críticos, incidentes, curva S.
* **Ações**: abrir obra, aceitar sugestão IA, exportar relatório.
* **Componentes**: KPI Cards, Curva S, Lista de Alertas, Mapa, Feed de Atividades.
* **Estados**: vazio (sem obra), alternância de escopo (obra→frente).

### 6.2 Planejamento — Gantt & Curva S (Web)

* **Objetivo**: montar/ajustar sequenciamento (EAP/WBS), janelas e marcos.
* **Ações**: *drag-drop*, dependências, bloquear janela, simulação “what-if”.
* **IA**: “Gerar plano inicial” a partir de catálogo + restrições.

### 6.3 OS — Lista/Kanban & Detalhe (Web/Mobile)

* **Objetivo**: distribuir, executar e acompanhar OS.
* **Detalhe OS**: status, janela, recursos, checklist, chat contextual, mídia, histórico (ES).
* **Ações**: delegar, apontar produção, anexar evidência, solicitar material, abrir inspeção.
* **Componentes**: WorkOrderCard, ChecklistRunner, MediaAnnotator, ActivityTimeline.

### 6.4 Alocação & Reserva — Timeline (Web)

* **Objetivo**: alocar equipes, equipamentos e janelas; resolver conflitos.
* **Ações**: arrastar/estender blocos, aceitar sugestão IA, aplicar política de prioridade.
* **Componentes**: AllocationTimeline, ResourceBadge, ConflictPanel.

### 6.5 Suprimentos — Requisição→OC→Recebimento (Web/Mobile)

* **Objetivo**: garantir material/equipamento na hora certa.
* **Ações**: criar requisição, enviar RFQ, aprovar OC, registrar recebimento em canteiro (scanner).
* **Componentes**: ProcurementBoard, ReceivingForm (com QR/NFC).

### 6.6 Qualidade & Segurança (Web/Mobile)

* **Objetivo**: inspeções, NCs, APR, incidentes.
* **Ações**: iniciar checklist, abrir NC, gerar ação corretiva, anexar evidências.
* **IA**: sugerir não-conformidade recorrente e mitigação.

### 6.7 Medições & Aprovação (Web)

* **Objetivo**: consolidar apontamentos → regras de medição → aprovação/aceite.
* **Ações**: simular medição, anexar evidência, solicitar aceite ao fiscal, emitir relatório.
* **Componentes**: MeasurementRun, EvidenceGallery.

### 6.8 Mobile — Hoje (Minha Jornada)

* **Objetivo**: ver tarefas/OS do dia, check-in geográfico, apontar produção.
* **Ações**: *one-tap* para iniciar/parar, ditado de notas (STT), upload offline.

---

## 7) Instrumentação (Product Analytics) & Telemetria

* **Eventos mínimos (nomenclatura)**:
  `view_*`, `click_*`, `submit_*`, `error_*`, `sync_*`, `ai_suggestion_viewed|accepted|dismissed`,
  `scanner_scan`, `media_uploaded`, `checkin_success`, `allocation_conflict_resolved`.
* **Propriedades**: `tenantId`, `obraId`, `role`, `offline`, `latency_ms`, `payload_size_kb`, `correlation_id`.
* **KPIs UX**: tempo para concluir apontamento, taxa de erro por formulário, latência p95 de salvar OS, adoção de sugestões IA.
* **Privacidade**: *hash* de IDs, redigir PII em *logs*, *opt-in* de *session replay*.

---

## 8) Segurança, LGPD & Compliance (no UX)

* **Menos é mais (PII)**: ocultar campos sensíveis por papel; *masking* e “mostrar/ocultar”.
* **Contexto de obra**: *scoping* visual explícito (badge de tenant/obra).
* **Termos & consent**: UI dedicada a consentimento de captura de mídia/dados de localização.
* **Trilha de auditoria**: “ver alterações” (quem/quando/o quê), com ID de correlação.

---

## 9) Entrega & Handoff

* **Figma**:

  * *Pages*: *Foundations*, *Components*, *Patterns*, *Screens (Web)*, *Screens (Mobile)*, *Prototypes*.
  * Auto-layout, *variants*, tokens em *Style Dictionary* (ou Figma Tokens).
* **Storybook**: docs MDX, *controls*, testes visuais (Chromatic), *a11y* add-on.
* **Testes**: Cypress (*happy-path* das jornadas), Playwright para *mobile-web*, Jest de componentes com *axe*.
* **Catálogo de contratos**: OpenAPI/GraphQL + AsyncAPI linkados a cada tela crítica.

---

## 10) Exemplos de Contratos de Componentes (TypeScript)

### 10.1 WorkOrderCard (resumo)

```ts
export type WorkOrderStatus = 'SCHEDULED'|'IN_PROGRESS'|'BLOCKED'|'DONE'|'CANCELLED';

export interface ResourceChip {
  kind: 'crew'|'equipment'|'material';
  label: string;
  qty?: number | string;
  severity?: 'info'|'warn'|'error';
}

export interface WorkOrderCardProps {
  id: string;
  title: string;
  wbsPath?: string;
  status: WorkOrderStatus;
  progressPct?: number;           // 0..100
  plannedWindow?: { start: string; end: string }; // ISO
  site?: string;
  chips?: ResourceChip[];
  onOpen?: (id: string) => void;
  onPrimaryAction?: (id: string) => void; // ex.: "Apontar produção"
}
```

### 10.2 AllocationTimeline (resumo)

```ts
export interface TimeBlock {
  id: string;
  resourceId: string;
  start: string; // ISO
  end: string;   // ISO
  woId?: string;
  draggable?: boolean;
  conflict?: boolean;
}

export interface AllocationTimelineProps {
  resources: { id: string; name: string; skill?: string; capacity?: number }[];
  blocks: TimeBlock[];
  viewport: { start: string; end: string };
  onMove?: (blockId: string, start: string, end: string) => void;
  onResolveConflict?: (blockId: string) => void;
  aiSuggestions?: { blockId: string; suggestion: string; apply: () => void }[];
}
```

---

## 11) Diretrizes Transversais

* **Performance budget**: TTI ≤ 3s (rede 4G), *bundle* crítico < 250KB, imagens otimizadas, virtualização pesada.
* **Estados ruins bem projetados**: sempre um CTA de saída (“tentar novamente”, “abrir suporte”).
* **IA com *guardrails***: revisão humana para ações de alto impacto (alocação em massa, cancelamentos).
* **Internacionalização**: pt-BR en-US, formatação local (datas, unidades), termos setoriais configuráveis.
* **Temas por tenant**: variação apenas em tokens; não altere layouts críticos.

---

## 12) Roadmap de UX (MVP → V2 → V3)

* **MVP (Fases 0–1)**: Minhas OS (mobile), Apontamentos, Scanner, OS Kanban (web), Alocação básica, Recebimento em canteiro, Inspeção simples, *skeletons* e offline-first.
* **V2 (Fases 2–3)**: Gantt + Curva S, ProcurementBoard completo, MeasurementRun, IA (alocação e risco), Copiloto RAG.
* **V3 (Fases 4–5)**: Visão computacional (EPI), simulações *what-if* avançadas, *white-label* completo, relatórios executivos customizáveis.

---

### Próximos passos sugeridos

1. **Kick-off de Figma** com *Foundations + 10 componentes + 8 telas MVP*.
2. **Storybook** mínimo viável com *a11y* e *visual regression*.
3. **Mapa de eventos** (analytics) acoplado às telas MVP.
4. **Guia de escrita** (microcopy) para mensagens de erro, alertas e IA.

