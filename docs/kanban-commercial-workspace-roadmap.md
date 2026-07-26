# Roadmap: Workspace Comercial do Kanban

Status: fonte de execucao da evolucao do Kanban

Documentos relacionados:

- [PRD do Kanban Comercial](./kanban-sales-prd.md)
- [Spec do Kanban Comercial](./kanban-sales-spec.md)
- [Auditoria tecnica de UI/UX](./kanban-ui-ux-technical-audit.md)
- [Roadmap do Editor de Automações](./kanban-visual-workflows-roadmap.md)

## Objetivo

Evoluir o Kanban para um workspace comercial leve, rapido e configuravel que substitua o uso operacional do Kommo sem transformar o Chatwoot em um CRM empresarial completo.

O produto tem dois usuarios principais:

- operador: secretaria, vendedor ou agente que precisa saber o que fazer agora;
- administrador: pessoa que configura funis, campos, regras, permissoes e governanca.

## Resultado Esperado

O operador deve conseguir:

- encontrar uma oportunidade em poucos segundos;
- abrir a conversa sem abrir o detalhe primeiro;
- entender etapa, valor, responsavel e proxima acao olhando o card;
- editar o essencial sem atravessar telas de configuracao;
- concluir a proxima acao e registrar o resultado;
- trabalhar por Kanban, lista ou atividades.

O administrador deve conseguir:

- criar um funil a partir de um template;
- configurar campos sem editar JSON;
- organizar abas, grupos, ordem e visibilidade;
- criar regras condicionais e obrigatoriedade por etapa;
- visualizar o impacto de uma alteracao antes de salvar;
- restaurar configuracoes e oportunidades arquivadas.

## Regras De Produto

- conversa e o contexto de atendimento;
- contato e a pessoa;
- oportunidade e o negocio em andamento;
- um contato pode ter varias oportunidades;
- o Kanban e orientado a venda, nao substitui o atendimento;
- automacoes ficam em modulo proprio, usando eventos do Kanban;
- nenhuma mensagem automatica deve ser enviada sem ativacao explicita;
- configuracao avancada usa divulgacao progressiva;
- operacoes destrutivas mostram impacto e possuem recuperacao;
- toda operacao comercial relevante e autorizada no backend.

## Legenda De Status

- `[ ]` pendente;
- `[-]` em andamento;
- `[x]` implementado localmente e aguardando validacao/deploy;
- `[v]` validado em producao;
- `[!]` bloqueado por dependencia ou decisao.

## Ordem De Entrega

1. P0 fecha a experiencia diaria e a confiabilidade do dado.
2. P1 aumenta produtividade, escala e previsibilidade.
3. P2 adiciona automacoes, governanca avancada e extensibilidade.

Nao iniciar uma etapa posterior para compensar uma lacuna de etapa anterior. Cada fase precisa fechar seus criterios de aceite antes da proxima.

## P0 - Operacao E Fundacao

### P0.1 Acoes Rapidas Do Card

Status: `[x]` local

- abrir conversa diretamente no card;
- abrir detalhes da oportunidade;
- selecionar card para acoes em massa;
- manter acoes com icones, labels acessiveis e tooltip;
- impedir que uma acao do card abra o detalhe por acidente.

Aceite:

- o botao de conversa aparece somente quando existe conversa vinculada;
- clique no botao nao dispara abertura do detalhe;
- teclado consegue focar e executar a acao;
- card manual continua sem botao de conversa;
- specs do card cobrem conversa vinculada e nao vinculada.

### P0.2 Workspace Do Operador

Status: `[x]` local; aguarda validacao visual e deploy

- reduzir o cabecalho a funil, busca, nova oportunidade e configuracoes;
- manter filtros, ordenacao, visao e filtros salvos em uma segunda linha;
- exibir resumo pequeno de abertas, valor, atrasadas e fechadas;
- tornar a selecao em massa visivel somente quando houver selecao;
- mostrar estados de carregamento, vazio, erro e sem permissao;
- preservar o contexto ao trocar entre Kanban, lista e atividades;
- remover informacao de marketing da leitura primaria do card;
- garantir que textos longos tenham truncamento com tooltip.

Aceite:

- operador identifica o proximo passo sem abrir o card;
- nenhum filtro ocupa uma linha inteira quando nao esta aberto;
- busca, filtros e ordenacao funcionam nas duas visoes;
- layout funciona sem sobreposicao em 1280px, 1024px e mobile;
- nenhuma acao essencial depende apenas de hover.

### P0.3 Drawer Da Oportunidade

Status: `[-]` estrutura consolidada localmente; falta validacao visual e deploy

- header fixo com contato, etapa, responsavel e status;
- resumo comercial sempre visivel;
- campos agrupados em Geral, Marketing e abas do cliente;
- timeline em aba propria, sem competir com formulario;
- rodape fixo com salvar, fechar, ganhar, perder e mais acoes;
- barra de alteracoes nao salvas;
- Escape, backdrop e foco de retorno consistentes;
- tela cheia no mobile.

Aceite:

- abrir e fechar nao perde dados digitados;
- foco inicial e foco de retorno sao previsiveis;
- erro de salvamento preserva todo o formulario;
- timeline mostra ator, evento, horario e alteracao;
- ganhar e perder usam o mesmo fluxo do arrastar.

### P0.4 Configuracao De Campos

Status: `[-]` editor visual em evolucao

- fluxo de criacao em nome, tipo e configuracao;
- grupos compactos por aba;
- dropzones visiveis por grupo;
- campos sem grupo em area separada;
- campo importante separado de campo obrigatorio;
- obrigatoriedade com checkbox por etapa;
- visibilidade condicional em linguagem natural;
- formula com autocomplete por `[` e preview;
- alerta de impacto antes de remover ou alterar campo usado;
- JSON somente em area avancada.

Aceite:

- administrador cria campo sem conhecer chave tecnica;
- campo pode ser movido para outra aba ou grupo;
- campo obrigatorio mostra em quais etapas sera exigido;
- condicao e formula mostram o resultado antes do salvamento;
- remover campo informa quantas oportunidades possuem dados;
- fechar com alteracao nao salva pede decisao explicita.

### P0.5 Qualidade Comercial Do Dado

Status: `[-]` base implementada; falta completar

- etapas com categoria aberta, ganha ou perdida;
- data prevista de fechamento;
- valor e moeda;
- responsavel comercial separado do agente da conversa;
- motivo de perda obrigatorio ao perder;
- aviso de possivel duplicidade sem bloquear casos legitimos;
- proxima acao com tipo, data, observacao e conclusao;
- historico de etapa, responsavel, valor e proxima acao.

Aceite:

- toda mudanca importante aparece na timeline;
- conflito entre dois editores nao sobrescreve dados silenciosamente;
- etapa terminal exige os dados corretos;
- oportunidade aberta sem proxima acao e claramente identificada;
- valores de moeda nao perdem centavos ou moeda original.

### P0.6 Busca, Lista E Atividades

Status: `[-]` visoes existentes; central e lista usam paginacao real; falta fechar escala e semantica visual

- busca por oportunidade, contato, telefone e email;
- lista para comparar, selecionar e trabalhar com volume;
- central de atividades com hoje, atrasadas, proximas, sem acao, agendamentos e por responsavel;
- filtro separado por responsavel comercial na central de atividades;
- filtros salvos com nome, renomear, aplicar e excluir;
- pagina ou cursor no backend para atividades e lista;
- carregar mais por etapa diretamente na visao em lista;
- filtros persistidos na URL quando compartilhamento fizer sentido.

Aceite:

- lista e Kanban exibem a mesma oportunidade;
- atividade abre o drawer mantendo contexto do board;
- filtro salvo nao depende de estado local perdido ao atualizar;
- resultado vazio explica como limpar ou ajustar filtros.
- busca e ordenacao sao aplicadas tambem no primeiro carregamento do board.

### P0.7 Acessibilidade E Mobile

Status: `[-]` foco e fechamento protegidos localmente; suíte E2E real preparada, faltam execução com ambiente semeado e leitor de tela

- foco inicial, foco de retorno e foco preso em drawers;
- teclado para todas as acoes do card e filtros;
- alternativa ao arrastar para mover card e campo;
- leitura por leitor de tela de etapa, valor, alerta e responsavel;
- contraste e foco visivel;
- testes em mobile estreito e tablet;
- mensagens de erro associadas ao campo.

Suíte automatizada: `tests/playwright/tests/e2e/ui/kanban-accessibility.spec.ts`, com projetos Desktop Chrome e Pixel 7. O fluxo é opt-in por `KANBAN_E2E=1` para evitar falsos positivos em ambientes sem board de teste.

Aceite:

- fluxo criar, editar, mover e fechar funciona sem mouse;
- foco nao desaparece apos salvar, erro ou fechar;
- nao existe dependencia de cor unica para status;
- nenhum texto ou botao sobrepoe outro em mobile.

## P1 - Produtividade E Escala

### P1.1 Acoes Em Massa

Status: `[-]` base existente; confirmacao de impacto detalhada localmente

- mover etapa;
- trocar responsavel;
- marcar ganha;
- marcar perdida;
- arquivar;
- restaurar;
- limpar selecao;
- resumo de impacto antes da execucao;
- feedback com sucesso parcial e erros por oportunidade.

### P1.2 Arquivamento

Status: `[x]` local; boards e oportunidades possuem arquivamento e restauracao

- arquivar e restaurar oportunidade;
- listar oportunidades arquivadas;
- arquivar e restaurar board;
- preservar cards, timeline, campos e configuracoes;
- diferenciar exclusao de arquivamento;
- bloquear arquivamento acidental sem confirmacao.

### P1.3 Configuracao Avancada De Pipeline

Status: `[-]` probabilidade, previsao ponderada e duplicacao de funil implementadas localmente; falta aceite visual e uso em previsao

- probabilidade por etapa;
- data prevista de fechamento;
- alertas de card parado;
- limite de cards como alerta, nunca bloqueio;
- templates versionados;
- duplicar board preservando configuracao;
- visualizacao de impacto antes de mudar etapa ou campo.

### P1.4 Inteligencia Comercial Leve

Status: `[-]` resumo comercial e exportacao filtrada implementados localmente; falta consolidar a visao analitica opcional

- valor aberto, ganho e perdido;
- conversao por etapa;
- tempo medio por etapa;
- motivos de perda;
- por responsavel;
- previsao simples por probabilidade;
- exportacao de lista filtrada.

Relatorios devem aparecer como resumo contextual e uma visao analitica opcional, sem poluir o fluxo diario.

## P2 - Automacao, Governanca E Extensibilidade

### P2.1 Fundacao De Automacoes

Status: `[-]` (base local implementada; aceite de producao pendente)

- eventos de card criado, etapa alterada, ganho, perda e proxima acao concluida;
- eventos comerciais do historico agora sao publicados depois do commit com contrato estavel e snapshot minimo;
- regras configuraveis por board com filtros de inbox, etapa, responsavel e campo;
- acoes internas de mover etapa, atribuir responsavel, definir proxima acao, preencher campo e arquivar;
- fila Sidekiq com chave idempotente por regra e evento;
- historico de execucao com estados `queued`, `running`, `succeeded`, `failed` e `skipped`;
- pausar, reativar e testar regra pela configuracao do board;
- falta apenas a validacao de producao com retries, volume e regras concorrentes.

### P2.2 Lembretes E Cadencias

Status: `[-]` (cadência interna e aniversário controlado implementados; aceite de produção pendente)

- cadencia configuravel por board com nome e passos de follow-up;
- cada passo define atraso em horas, tipo de proxima acao e observacao interna;
- inscricao manual no detalhe da oportunidade;
- job Sidekiq a cada cinco minutos transforma passo vencido em proxima acao interna;
- centro de atividades continua sendo a superficie de trabalho e lembrete do operador;
- aba de agendamentos usa `starts_at` para listar consultas/reunioes de hoje e futuras;
- lembrete interno configuravel por board cria uma proxima acao antes do `starts_at`;
- o lembrete interno nao sobrescreve uma proxima acao manual e usa lock para evitar duplicidade;
- pausa quando cliente responde, ganha, perde ou arquiva a oportunidade;
- nenhum passo envia mensagem ao cliente.

Ainda pendente nesta fase:

- notificacao push/email no sistema de notificacoes do Chatwoot;
- limites de frequencia, consentimento, opt-out e fuso horario por contato;
- inscricao automatica por etapa e historico de execucao de cada passo.

### P2.3 Aniversarios Do Contato

Status: `[x]` local; aceite de produção pendente

- `date_of_birth` pertence ao contato;
- aniversario e recorrente, nao depende de oportunidade;
- provisionamento idempotente por conta;
- considerar timezone e horário configurados;
- exigir opt-in antes de WhatsApp/email;
- respeitar janela do WhatsApp ou template aprovado;
- registrar entrega por ano/canal com sucesso, falha e retry idempotente.

### P2.4 Governanca

Status: `[-]` permissões comerciais implementadas; auditoria e retenção pendentes

- permissoes por board e operacao (`kanban_view`, `kanban_create`, `kanban_edit`, `kanban_assign`, `kanban_move`, `kanban_close`, `kanban_bulk`, `kanban_configure`, `kanban_manage`, `kanban_report`);
- historico de configuracao;
- auditoria de campos;
- restauracao de versao do board;
- exportacao e retencao;
- politica de dados pessoais;
- segregacao entre administrador, gestor e operador.

### P2.5 Extensibilidade

Status: `[ ]`

- eventos publicados para integracoes;
- endpoints estaveis;
- webhooks de oportunidade;
- campos de marketing preservando chaves canonicas;
- integracao futura com calendario sem acoplar o Kanban a um fornecedor.

### Contrato De Eventos Comerciais

Os eventos derivados de `KanbanCardEvent` nao enviam mensagens e nao executam regras por conta propria. Eles apenas publicam, depois do commit, um payload estavel para o modulo de automacoes e integracoes:

- `kanban.card.stage_changed`;
- `kanban.card.owner_changed`;
- `kanban.card.amount_changed`;
- `kanban.card.custom_fields_changed`;
- `kanban.card.next_action_scheduled`;
- `kanban.card.next_action_completed`;
- `kanban.card.won`;
- `kanban.card.lost`;
- `kanban.card.reopened`;
- `kanban.card.archived`;
- `kanban.card.restored`.

O payload contem `account_id`, `board_id`, `stage_id`, `card_id`, `contact_id`, `conversation_id`, `owner_id`, `event_id`, `event_type`, `occurred_at`, `change_set` e `metadata`. O evento `kanban.card.created` continua sendo publicado pelos servicos de criacao existentes para preservar compatibilidade.

## Arquitetura De Interface Alvo

Extrair o componente atual grande em unidades testaveis:

- `KanbanWorkspaceShell`;
- `KanbanBoardToolbar`;
- `KanbanSummaryBar`;
- `KanbanFiltersPanel`;
- `KanbanStageColumn`;
- `KanbanOpportunityCard`;
- `KanbanOpportunityDrawer`;
- `KanbanOpportunityTimeline`;
- `KanbanActivityCenter`;
- `KanbanFieldManager`;
- `KanbanFieldInspector`;
- `KanbanRuleBuilder`.

Usar componentes e dependencias ja existentes no Chatwoot antes de adicionar novas bibliotecas.

## Contratos De Dados

Campos estaveis devem manter:

- `key`;
- `label`;
- `field_type`;
- `required_stage_ids`;
- `condition`;
- `formula`;
- `layout`.

Toda alteracao de configuracao deve preservar dados existentes ou informar impacto. Toda alteracao de oportunidade deve gerar evento comercial auditavel.

## Metricas De Aceite

- tempo para criar oportunidade;
- tempo para abrir conversa a partir do card;
- tempo para localizar oportunidade;
- percentual de oportunidades abertas com proxima acao;
- percentual de cards atrasados;
- taxa de erro em salvamento;
- tempo para configurar um board do template;
- tarefas concluídas sem mouse;
- taxa de sucesso em mobile;
- quantidade de configuracoes abandonadas.

## Definition Of Done

Cada entrega somente pode ser marcada como concluida quando:

- teste unitario ou de componente cobre o comportamento;
- backend possui policy/service e validacao quando aplicavel;
- portugues e ingles estao traduzidos;
- desktop e mobile foram revisados;
- teclado e foco foram revisados;
- erro, vazio, carregamento e permissao foram testados;
- `git diff --check`, lint e specs relevantes passam;
- migracoes, deploy e smoke test estao documentados quando houver banco;
- o PR registra como testar pela perspectiva do operador.

## Aceite De Producao Pendente

Antes de publicar a imagem final, executar no Swarm:

- migration e smoke test em API, Admin e Sidekiq;
- dois agentes editando e movendo a mesma oportunidade, verificando que o último estado válido não cria posições duplicadas;
- processamento de aniversário em retry concorrente, verificando uma entrega por ano/canal;
- board com volume representativo de cards, paginação, busca, lista, filtros e abertura do drawer;
- jobs de aniversário e cadência com Redis/Sidekiq disponíveis e falha de canal registrada sem loop infinito;
- Playwright em desktop e Pixel 7, seguido de VoiceOver/NVDA para drawer, abas, erros e foco de retorno.

As specs locais de concorrência do Kanban cobrem reordenação, criação manual e criação automática concorrentes. A spec de aniversário cobre idempotência e processamento em lotes; o aceite acima valida a mesma garantia com a topologia real de produção.

## Inicio Da Execucao

Entrega iniciada nesta rodada:

- acao direta para abrir a conversa a partir do card;
- teste de componente para conversa vinculada;
- migration `20260724100000_add_probability_to_kanban_stages.rb` para probabilidade por etapa;
- drawer e workspace agora estao consolidados localmente; a proxima validacao e E2E visual em desktop, mobile e teclado.

## Registro De Implementacao

- `[x]` cabecalho do workspace reorganizado em linha primaria e linha secundaria;
- `[x]` busca movida para a linha primaria, com filtros, ordenacao, visao e filtros salvos na linha secundaria;
- `[x]` resumo comercial compactado em faixa horizontal responsiva;
- `[x]` truncamento de nomes longos de etapa com tooltip;
- `[x]` fechamento do drawer protegido contra perda de alteracoes, inclusive por Escape e backdrop;
- `[x]` foco devolvido ao disparador ao fechar o drawer e a central de atividades;
- `[x]` alternativa acessivel ao arrastar: mover oportunidade por seletor de etapa no card;
- `[x]` central de atividades carregando por board com filtros de hoje, atrasadas, proximas, sem acao e responsavel;
- `[x]` central de atividades com aba de agendamentos ordenada por data/hora de inicio;
- `[x]` endpoint de atividades com autorizacao, filtro por responsavel e paginacao limitada;
- `[x]` filtro de responsavel comercial separado do agente da conversa;
- `[x]` busca e ordenacao aplicadas no carregamento inicial do board;
- `[x]` visao em lista permite carregar mais cards por etapa;
- `[x]` confirmacao em massa informa operacao, quantidade e destino ou motivo antes de executar;
- `[x]` arquivamento em massa informa a quantidade selecionada e permite restauracao;
- `[x]` probabilidade de ganho por etapa com migration, constraint de 0 a 100 e defaults para ganho/perda;
- `[x]` previsao ponderada no resumo compacto, calculada somente para oportunidades abertas;
- `[x]` duplicacao de funil preservando configuracoes, etapas, acesso e sem copiar oportunidades;
- `[x]` exportacao CSV filtrada com dados comerciais e campos personalizados;
- `[x]` validacao local: 9 arquivos de teste, 345 testes frontend aprovados, 8 exemplos Rails de relatorios aprovados, 45 exemplos Rails de etapas/modelo aprovados, lint e `git diff --check`.
