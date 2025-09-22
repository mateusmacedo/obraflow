# Contexto de Construção Civil Brasileira - ObraFlow

Este documento apresenta uma descrição técnica detalhada dos principais manuais, documentos e instrumentos normativos usados em projetos de construção civil no Brasil, integrados com os padrões técnicos e arquiteturais do ObraFlow.

## 🏗️ Arquitetura Técnica Integrada

O ObraFlow foi projetado como um **monorepo multilíngue** (TypeScript + Go) seguindo padrões de **Domain-Driven Design (DDD)**, **Clean Architecture** e **CQRS+EDA**, otimizado para o contexto específico da construção civil brasileira.

### Stack Tecnológica
- **Frontend**: Next.js 14 (App Router) + React Native/Expo (mobile offline-first)
- **Backend**: NestJS (BFF) + Go Echo + Fx + Watermill (microserviços)
- **Observabilidade**: OpenTelemetry → Tempo/Jaeger + Prometheus + Loki + Grafana
- **Dados**: PostgreSQL (RLS multi-tenant) + MongoDB + Redis + TimescaleDB
- **CI/CD**: GitHub Actions + Nx + pnpm + Changesets

---

## Principais documentos/manuais e seu propósito

| Documento/Manual                                                | Propósito principal                                                                                                                                                    | Quando é usado                                                                                                              | Papel no planejamento, medições e execução                                                                                                                                                                                                                                                                                |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Manual de Obras Públicas / Manual de Práticas da Construção** | Normatizar procedimentos gerais de obras públicas, definindo padrões de execução, controle, fiscalização, medição e recebimento de obras.                              | Contratos públicos federais (ou estaduais/municipais) que exigem regularidade, conformidade com legislação vigente.         | Serve de referência para: \* elaboração de projetos executivos; \* critérios de medição e recebimento; \* exigências de qualidade, segurança, licenças; \* cronogramas físicos-financeiros; \* sistemática de fiscalização. Ex: *Manual de Obras Públicas — Edificações* da SEAP. ([Serviços e Informações do Brasil][1]) |
| **Manual de Projeto**                                           | Estabelece critérios e procedimentos para elaboração de projetos (arquitetônico, estrutural, complementares) de forma organizada e normatizada.                        | Antes da execução, quando se definem os desenhos, memórias, compatibilização das disciplinas, níveis de detalhamento.       | Inclui: desenhos normativos, memórias de cálculo, memorial descritivo, compatibilização de disciplinas, normas técnicas aplicáveis, critérios de aprovação, revisões, formatos de entrega. ([Serviços e Informações do Brasil][2])                                                                                        |
| **Projeto Básico**                                              | Fornecer elementos suficientes para caracterizar a obra/serviço, permitir estimativa de custo, viabilidade técnica, licitação.                                         | Fase de licitação pública ou definição inicial do escopo do empreendimento.                                                 | Deve conter solução escolhida, definições técnicas globais e localizadas, identificação de serviços/materiais, equipamentos, métodos de execução provisórios, cronograma, orçamento estimado, estudo de impacto (ambiental, urbanístico) se aplicável. ([Prodi IFES][3])                                                  |
| **Projeto Executivo**                                           | Detalhar todos os elementos necessários para a execução precisa da obra, em todas as disciplinas.                                                                      | Após aprovação do Projeto Básico e licitação, para execução da obra (fundações, estruturas, instalações, acabamento, etc.). | Desenhos, esquemas, detalhes construtivos, memórias técnicas, especificações de materiais, quantitativos de serviços, compatibilizações, prazos, métodos de execução, possíveis tolerâncias, instruções especiais. ([Serviços e Informações do Brasil][2])                                                                |
| **Caderno de Encargos / Caderno de Especificações Técnicas**    | Especificar obrigações do contratado, critérios de desempenho, normas, métodos de execução, qualidade, medição, fiscalização.                                          | Integra edital/licitação ou contrato de obras e serviços de engenharia.                                                     | Inclui: discriminação técnica dos serviços, especificações de materiais, critérios de medição, prazos, etapas e fases de execução, procedimentos de fiscalização, condições contratuais, penalizações, responsabilidades. Exemplo: Caderno de Encargos da Polícia Federal. ([Serviços e Informações do Brasil][4])        |
| **Memorial Descritivo / Memorial Técnico**                      | Apresentar descrição detalhada dos sistemas, materiais, métodos construtivos, acabamentos, complementares, para que se tenha entendimento claro do que será executado. | Normalmente junto ou como parte do Projeto Executivo ou do Caderno de Encargos.                                             | Deve ter: definições de materiais (especificações físicas e de desempenho), sistema construtivo, acabamentos, tolerâncias, interfaces entre especialidades, referências normativas, condições de uso. ([Portal IFBA][5])                                                                                                  |
| **Manual de Uso, Operação e Manutenção**                        | Após finalização da obra, orientar o proprietário/usuário para uso correto, operação dos sistemas instalados, manutenção preventiva e corretiva, garantias.            | Entrega da obra, como parte do contrato de conclusão, também exigido por normas de desempenho ou financiamento.             | Inclui: instruções de operação (sistemas elétricos, hidrossanitários, climatização, elevadores, etc.), cronograma de manutenção, fornecedores, garantias, prazos, rotinas de inspeção, limpeza, substituição de peças. Exemplo do Guia da CBIC para esse tipo de manual. ([CBIC][6])                                      |

---

## Informações típicas que esses documentos contêm

Para que haja clareza no planejamento, medição, execução, os documentos acima normalmente trazem estas informações:

* **Descrição do escopo** de serviços a serem executados, por disciplina (arquitetura, estrutura, instalações elétricas, hidráulicas, etc.).
* **Quantitativos de materiais e serviços**: estimativas físicas (volume, área, unidades), serviços unitários.
* **Composições de preço unitário**: insumos (material, mão de obra, equipamentos, transporte), índices ou fatores de produtividade.
* **Normas técnicas de referência**: ABNT, normas setoriais, legislação municipal/estadual/federal.
* **Critérios de qualidade e tolerâncias**: aceitáveis em acabamento, em posicionamento, em nivelamento, prumo, esquadro, juntas, etc.
* **Métodos / etapas de execução**: procedimentos construtivos, condições iniciais do terreno, instalações provisórias, organização do canteiro.
* **Cronograma físico-financeiro**: etapas, prazos, desembolsos estimados por fase ou serviço.
* **Formas e critérios de medição / aferição**: como medir avanço físico (por serviço, por etapa), documentos aceitos, prazos para apresentação de medições, planilhas, procedimentos para rejeição ou ajuste.
* **Fiscalização e controle**: quem fiscaliza, papéis/responsabilidades, auditorias, registros, aceitação provisória e definitiva, recebimento, penalidades.
* **Garantias, manutenção e operação futura**: prazos de garantia, fornecedores, assistência técnica, manuais de operação/dispositivos instalados.

---

## Relação legal e normativas aplicáveis no Brasil

* A Lei de Licitações e Contratos (Lei nº 8.666/1993, e mais recentemente a Lei nº 14.133/2021), exige que obras públicas tenham projetos básicos ou executivos adequados, que licitações especifiquem serviço, orçamento, critérios de medição etc.
* Normas da ABNT, por exemplo: normas para elaboração de projetos, desempenho de edificações (NBR 15575), manutenção de edificações (NBR 5674), diretrizes para manuais de uso e manutenção.
* Regulamentações relacionadas à segurança do trabalho, meio ambiente, licenças municipais, normas técnicas específicas de cada tipo de serviço (por exemplo elétrico, hidráulico, estruturas, etc.).

---

## 🔄 Integração com Padrões Técnicos do ObraFlow

### Mapeamento de Documentos para Domínios de Software

| Documento Normativo | Domínio ObraFlow | Implementação Técnica |
|---------------------|------------------|----------------------|
| **Manual de Obras Públicas** | Planning + Work-Management | EAP/WBS, cronograma, curva S |
| **Projeto Básico/Executivo** | Resource-Orchestration | Alocação de recursos, janelas |
| **Caderno de Encargos** | Quality & Safety | Inspeções, NCs, procedimentos |
| **Memorial Descritivo** | Measurement & Billing | Critérios de medição, regras |
| **Manual de Uso/Manutenção** | Field-Ops | Checklists, diário de obra |

### Padrões de Qualidade Integrados

- **Testes**: Cobertura ≥80% (unit + integration + e2e)
- **Observabilidade**: TraceId ponta-a-ponta, métricas p95/p99
- **Segurança**: SAST, SBOM, image scanning, dependency review
- **Performance**: <100ms p95, >1000 RPS por tenant
- **Compliance**: LGPD, auditoria, trilha de alterações

### Estrutura de Monorepo Aplicada

```
obraflow/
├── apps/
│   ├── web-next/              # Dashboard executivo
│   ├── mobile-expo/           # Campo offline-first
│   ├── bff-nest/              # API Gateway
│   └── svc-accounts-go/       # Microserviços Go
├── libs/
│   ├── ts/framework-core/     # DDD patterns
│   ├── ts/logging-pino/       # Logging estruturado
│   ├── ts/otel-sdk/           # Observabilidade
│   └── go/pkg/tenancy/        # Multi-tenancy
└── tools/generators/          # Scaffolds padronizados
```

---

Se quiser, posso te preparar um **modelo de estrutura de documento** (por exemplo do "Caderno de Encargos + Memoriais + Especificações + Critérios de Medição") pra usar como guia, ou mostrar exemplos de documentos normativos atuais pra sua região (SP ou nacional). Deseja que faça isso?

[1]: https://www.gov.br/compras/pt-br/acesso-a-informacao/manuais/manual-obras-publicas-edificacoes-praticas-da-seap-manuais/manual_obraspublicas_construcao.pdf?utm_source=chatgpt.com "Manual de Obras Públicas-Edificações - Portal Gov.br"
[2]: https://www.gov.br/compras/pt-br/acesso-a-informacao/manuais/manual-obras-publicas-edificacoes-praticas-da-seap-manuais/manual_obraspublicas_projeto.pdf?utm_source=chatgpt.com "Manual de Obras Públicas-Edificações - Portal Gov.br"
[3]: https://prodi.ifes.edu.br/images/stories/Prodi/Atividades/070.100.030.065.pdf?utm_source=chatgpt.com "MANUAL DE PROCEDIMENTOS Elaborar Projetos de Obras"
[4]: https://www.gov.br/pf/pt-br/assuntos/licitacoes/2022/distrito-federal/tomadas-de-precos/tomada-de-precos-no-1-2022-sr-pf-df/edital-da-tomada-de-precos-no-1-2022-sr-pf-df-uasg-200228/1-1-2-anexo-ii-do-pb-caderno-de-encargos-e-especificacoes-tecnicas.pdf?utm_source=chatgpt.com "Caderno de Encargos e Especificações Técnicas - Portal Gov.br"
[5]: https://portal.ifba.edu.br/eunapolis/textos-fixos-campus-eunapolis/documentos-materias/documentos-materias-2020/anexo-vi-memorial-descritivo-e-especificacoes.pdf?utm_source=chatgpt.com "MEMORIAL DESCRITIVO / ESPECIFICAÇÕES TÉCNICAS ..."
[6]: https://cbic.org.br/wp-content/uploads/2017/11/Guia_de_Elaboracao_de_Manuais_2014.pdf?utm_source=chatgpt.com "GUIA NACIONAL PARA A ELABORAÇÃO DO MANUAL ..."
