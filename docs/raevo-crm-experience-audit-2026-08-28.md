# Auditoria de Experiencia Raevo CRM

Data: 28 de agosto de 2026
Escopo: Kanban, oportunidade, Agenda, Financeiro e Formulários
Método: `ui-ux-pro-max`, `frappe-ui-patterns`, `web-design-guidelines`, `ui-visual-validator`, `accessibility-compliance`, `agentic-browser-testing`, `visual-testing` e revisão estática do código.

## Resultado executivo

O produto já tem uma base funcional incomum para um CRM construído sobre Chatwoot: oportunidades, etapas, campos por aba/grupo, linha do tempo, Agenda, cobrança, Formulários e automação têm contratos próprios e testes focados. O problema central agora é de **orquestração da experiência**. A mesma tela frequentemente tenta atender operação, consulta, configuração e auditoria ao mesmo tempo. Isso aumenta a carga cognitiva e dá a sensação de interface técnica, ainda que o domínio esteja correto.

Direção recomendada: consolidar o produto como uma **Mesa Comercial**. O Kanban ocupa a tela; o detalhe abre ao lado; Agenda e Financeiro são visões operacionais independentes; configurações vivem em páginas de administração progressiva, sem competir com quem está atendendo.

## Evidência de qualidade atual

- A suíte focada executada nesta auditoria passou: **8 arquivos, 254 testes**. Cobriu `KanbanView`, detalhe da oportunidade, Agenda, detalhe de agendamento, Financeiro, criação de cobrança, Formulários e convites.
- Há roteiros Playwright para Kanban e Agenda, inclusive foco de modal, teclado, mudança de visão, criação, reagendamento e cancelamento. Eles ainda não foram executados nesta sessão: requerem servidor em execução, base de dados semeada e credenciais E2E próprias. A auditoria ao vivo e a regressão por screenshot ficam pendentes até esse ambiente estar disponível.
- Há boa intenção de acessibilidade: botões de ícone usam `aria-label`/`title`, o drawer de oportunidade usa `role=dialog`, `aria-modal`, tabs e retorno de foco; a Agenda possui controles semânticos e as ações principais têm alternativa via detalhe.

## Achados prioritários

### P0 - Trabalho operacional e administração concorrem na mesma tela

**Impacto:** alto. A pessoa que responde clientes enxerga controles de configuração, relatórios, exportação e automação próximos à ação de criar/mover oportunidade. Isso torna a navegação menos óbvia e aumenta risco de ação acidental.

**Evidência:**
- O menu de três pontos do Kanban reúne arquivados, criação de etapa, exportação, resumo de vendas, automações e configurações em [KanbanView.vue](../app/javascript/dashboard/routes/dashboard/kanban/KanbanView.vue:1800).
- A primeira dobra do Financeiro, para administradores, exibe ativação do módulo, mercado, segurança e conexão antes ou junto da lista de cobranças em [FinanceView.vue](../app/javascript/dashboard/routes/dashboard/finance/FinanceView.vue:569).
- A configuração da Agenda concentra cadastro, disponibilidade, Google e link público no mesmo diálogo em [CalendarSettingsDialog.vue](../app/javascript/dashboard/routes/dashboard/calendar/CalendarSettingsDialog.vue:899).

**Recomendação:** separar claramente:
1. `Trabalhar`: quadro/lista, Hoje, Agenda e cobranças.
2. `Configurar`: funil, campos, procedimentos/agendas, disponibilidade, provedor financeiro, formulários e automações.
3. `Analisar`: relatórios, exportações, auditoria e histórico.

### P0 - Cabeçalhos estão orientados por controles, não por decisão

**Impacto:** alto. Busca, filtros, mudança de visão e ações competem visualmente em cada módulo. A pessoa precisa decodificar controles antes de entender onde está e qual é a próxima ação.

**Evidência:**
- O cabeçalho do Kanban usa o campo de busca também para abrir o diálogo de filtros, em [KanbanView.vue](../app/javascript/dashboard/routes/dashboard/kanban/KanbanView.vue:1717). A função de buscar e a de configurar filtro são conceitualmente diferentes.
- O cabeçalho da Agenda agrupa recursos, status, busca, período, navegação e modo de calendário na mesma faixa em [CalendarView.vue](../app/javascript/dashboard/routes/dashboard/calendar/CalendarView.vue:270).
- Filtros do Financeiro ocupam uma grade inteira logo acima da lista em [FinanceView.vue](../app/javascript/dashboard/routes/dashboard/finance/FinanceView.vue:745).

**Recomendação:** uma barra operacional de no máximo duas linhas: contexto à esquerda, busca no centro, ação principal à direita; filtros em popover/drawer persistente com contador. A busca deve filtrar instantaneamente e o botão `Filtros` deve abrir critérios e filtros salvos.

### P0 - O detalhe da oportunidade continua sendo uma tela ampla demais

**Impacto:** alto. Hoje o drawer comporta título, funil, etiquetas, contato, Agenda, Financeiro, Formulários, linha do tempo e grupos de campos. Tudo é válido, mas a estrutura permite que o usuário perceba todos os domínios como campos equivalentes.

**Evidência:**
- O drawer tem largura máxima de 88rem fora do modo lateral em [KanbanOpportunityDetailsModal.vue](../app/javascript/dashboard/routes/dashboard/kanban/KanbanOpportunityDetailsModal.vue:1242).
- A navegação mistura abas operacionais (`Geral`, `Contato`, `Agenda`, `Financeiro`, `Formulários`) e `Linha do tempo` em [KanbanOpportunityDetailsModal.vue](../app/javascript/dashboard/routes/dashboard/kanban/KanbanOpportunityDetailsModal.vue:1448).
- `Próxima ação`, responsável, observação, valor e previsão aparecem como blocos de formulário no mesmo plano visual em [KanbanOpportunityDetailsModal.vue](../app/javascript/dashboard/routes/dashboard/kanban/KanbanOpportunityDetailsModal.vue:1513).

**Recomendação:** drawer lateral de 560-640px por padrão, com:
- cabeçalho de oportunidade: título editável, etapa, responsável, tags e conversa;
- bloco `Agora`: próxima ação, situação, alerta e único CTA principal;
- abas de domínio: `Resumo`, `Contato`, `Agenda`, `Financeiro`, `Formulários`, `Histórico`;
- em cada aba, campos em linhas compactas, título como rótulo de input, grupos recolhíveis e somente itens preenchidos ou importantes abertos;
- configuração de campos fora do drawer, com atalho que abre a tela administrativa correta.

### P1 - Densidade e hierarquia inconsistentes

**Impacto:** médio-alto. Cartões, blocos e painéis usam muitos contornos, fundo e sombra semelhantes. Isso cria "caixas dentro de caixas" e reduz a leitura rápida.

**Evidência:**
- Financeiro inicia com cartões de módulo e segurança, segue para outro cartão de cobranças e, dentro dele, cartões de resumo em [FinanceView.vue](../app/javascript/dashboard/routes/dashboard/finance/FinanceView.vue:569).
- O editor de Formulários usa barra lateral fixa, seções grandes e cartões consecutivos em [FormsView.vue](../app/javascript/dashboard/routes/dashboard/forms/FormsView.vue:733).
- A configuração de disponibilidade fica como painel dentro do painel de recursos em [CalendarSettingsDialog.vue](../app/javascript/dashboard/routes/dashboard/calendar/CalendarSettingsDialog.vue:1389).

**Recomendação:** usar superfícies planas em faixas de página; reservar borda para lista, modal e item selecionado. Densidade alvo no desktop: linha de lista 44-52px, card de Kanban 96-120px, seção de detalhe 8px entre linhas e 20-24px entre blocos.

### P1 - Texto importante ainda pode ser cortado

**Impacto:** médio. O contexto comercial se perde em nomes reais de funil, oportunidade, paciente e cobrança.

**Evidência:**
- Nome do funil usa `truncate` no seletor de quadro em [KanbanView.vue](../app/javascript/dashboard/routes/dashboard/kanban/KanbanView.vue:1683).
- Título do drawer usa `truncate` em [KanbanOpportunityDetailsModal.vue](../app/javascript/dashboard/routes/dashboard/kanban/KanbanOpportunityDetailsModal.vue:1256).
- Agenda usa `truncate` em título de página e texto de consulta em [CalendarView.vue](../app/javascript/dashboard/routes/dashboard/calendar/CalendarView.vue:283) e [CalendarView.vue](../app/javascript/dashboard/routes/dashboard/calendar/CalendarView.vue:519).
- Financeiro corta contato, oportunidade e responsável em [FinanceView.vue](../app/javascript/dashboard/routes/dashboard/finance/FinanceView.vue:857).

**Recomendação:** nenhuma entidade de negócio deve depender apenas de elipse. Em títulos, usar quebra em até duas linhas e tooltip/`title`; em tabelas, permitir expansão no detalhe ou aumentar a coluna crítica.

### P1 - Foco e acessibilidade existem, mas não estão fechados na jornada inteira

**Impacto:** médio. Há bons blocos de acessibilidade, porém popovers e estados dinâmicos precisam de uma validação completa no navegador.

**Evidência:**
- O popover de filtros do Kanban declara `role=dialog`, mas a revisão estática não encontrou `aria-modal`, foco inicial ou retorno de foco específico no seu fluxo em [KanbanView.vue](../app/javascript/dashboard/routes/dashboard/kanban/KanbanView.vue:1925).
- O calendário tem drag-and-drop para reagendamento em [CalendarView.vue](../app/javascript/dashboard/routes/dashboard/calendar/CalendarView.vue:497); o drawer de detalhe é a alternativa apropriada, mas isso deve ser explicitamente anunciado e testado por teclado.
- As month pills da Agenda usam `truncate`; precisam de nome acessível completo quando o texto visual for reduzido.

**Recomendação:** padronizar um componente de popover modal leve: foco no primeiro controle, `Escape`, clique externo, foco de retorno e anúncio de filtro aplicado. Executar a matriz E2E abaixo antes de liberar o redesenho.

## Proposta de arquitetura de informação

| Área | Trabalho diário | Configuração | Análise |
| --- | --- | --- | --- |
| Kanban | quadro, lista, Hoje, oportunidade | funil, etapas, campos, permissões | conversão, ciclo, gargalos |
| Agenda | dia/semana, agendar, remarcar, check-in | agendas, procedimentos, horários, página pública | comparecimento, ocupação |
| Financeiro | cobranças, envio de link, confirmação | módulo, provedor, permissões, fiscal | recebido, vencido, por procedimento |
| Formulários | convites e respostas vinculadas | modelos, versões, mapeamentos, acesso | conclusão, abandono, qualidade |

## Critérios de aceite para o redesenho

1. Uma secretaria abre oportunidade, edita responsável/próxima ação, registra agendamento, gera cobrança e envia o link sem trocar de contexto mais de duas vezes.
2. Configurações não aparecem na primeira dobra do quadro, Agenda ou Financeiro para usuários operacionais.
3. Busca e filtros têm papéis distintos, botão claro para fechar/aplicar/limpar/salvar e contador de filtros ativos.
4. Todo drawer, modal e popover prende e devolve foco corretamente; `Escape` fecha sem perder a referência de origem.
5. Títulos longos de oportunidade, etapa, procedimento, contato e cobrança não ficam inacessíveis por truncamento.
6. Arrastar cards/agendamentos tem alternativa de teclado e ação explícita pelo detalhe.
7. Desktop 1280px e 1440px não têm sobreposição, scroll horizontal acidental ou ação primária fora da área visível.
8. Screenshots de Kanban, detalhe, Agenda, Agenda/configuração, Financeiro e Formulários são aprovados como baseline antes de cada release visual.

## Plano de validação E2E pendente

Ambiente necessário: Rails/Vite, banco semeado, usuário E2E, uma oportunidade, uma consulta e uma cobrança de teste. Os arquivos existentes já dão ponto de partida: `tests/playwright/tests/e2e/ui/kanban-accessibility.spec.ts` e `tests/playwright/tests/e2e/ui/calendar-workspace.spec.ts`.

1. **Kanban:** abrir quadro, buscar, aplicar/salvar/remover filtro, criar oportunidade, editar campo, mover etapa sem drag, abrir conversa, abrir/fechar drawer e restaurar foco.
2. **Agenda:** criar procedimento/agenda/horário, agendar, reagendar, cancelar, alterar status, abrir oportunidade e retornar; validar recorrência.
3. **Financeiro:** usuário operacional cria cobrança, copia/prepara link, confirma manual permitida; administrador configura provedor; usuário sem permissão não vê configuração.
4. **Formulários:** criar modelo, publicar, gerar convite individual de anamnese, responder, conferir ausência de dado sensível na oportunidade/automação e auditoria de leitura.
5. **Acessibilidade:** teclado completo, leitor de tela para nomes/estado, zoom de 200%, contraste, mensagens de erro e recuperação de falha.
6. **Visual:** desktop 1280/1440 para cada área; congelar datas/avatares; usar screenshot baseline e anexar diff em CI.

## Limites desta auditoria

Esta revisão reuniu evidência estática, testes de componente e os roteiros Playwright existentes. A execução live com Playwright/Chrome não foi possível nesta sessão porque não havia servidor local em execução nem um conector de navegador disponível. Portanto, nenhum achado visual foi marcado como "aprovado em produção" sem screenshot ou interação real.
