# Spec: Fluxos Visuais Do Kanban

## Escopo Técnico

O construtor é implementado em Vue 3 com `@vue-flow/core`, `@vue-flow/background` e `@vue-flow/controls`. O canvas persiste sua definição em `KanbanAutomationRule.flow_definition`; a execução usa Sidekiq e PostgreSQL.

## Persistência

### `kanban_automation_rules`

| Campo             | Tipo                              | Uso                                               |
| ----------------- | --------------------------------- | ------------------------------------------------- |
| `flow_definition` | `jsonb`, obrigatório, padrão `{}` | Nós, arestas, posições e configuração de cada nó. |

Uma regra sem `flow_definition.nodes` continua usando o formato legado `actions`.

### `kanban_automation_executions`

| Campo            | Tipo                              | Uso                                                                                          |
| ---------------- | --------------------------------- | -------------------------------------------------------------------------------------------- |
| `workflow_state` | `jsonb`, obrigatório, padrão `{}` | Próximo nó a executar durante uma espera.                                                    |
| `scheduled_at`   | `datetime`                        | Quando `ContinueWorkflowJob` deve retomar a execução.                                        |
| `status`         | enum string                       | `queued`, `running`, `waiting`, `succeeded`, `failed`, `skipped`.                            |
| `kanban_card_id` | referência opcional               | Oportunidade usada na execução, inclusive após o evento original deixar de estar disponível. |
| `automation_snapshot` | `jsonb`, obrigatório, padrão `{}` | Cópia imutável de condições, ações, canvas e versão da regra no início da execução. |

Índice: `(status, scheduled_at)` para diagnóstico e consultas de execuções aguardando.

### `kanban_automation_connections`

| Campo           | Tipo            | Uso                                                                  |
| --------------- | --------------- | -------------------------------------------------------------------- |
| `name`          | string          | Nome legível, único por funil.                                       |
| `webhook_url`   | string          | Endpoint HTTPS sem credenciais embutidas.                            |
| `secret`        | texto protegido | Chave para assinatura HMAC SHA-256. Nunca retorna nas listagens.     |
| `active`        | boolean         | Uma conexão inativa não pode ser escolhida por um nó.                |
| `inbound_token` | string secreta  | Identifica o endpoint de entrada e nunca dispensa a assinatura HMAC. |

### `kanban_automation_rule_versions`

| Campo                       | Tipo      | Uso                                                                                         |
| --------------------------- | --------- | ------------------------------------------------------------------------------------------- |
| `kanban_automation_rule_id` | referência | Regra a que a versão pertence.                                                              |
| `account_id`                | referência | Mantém o isolamento de conta e permite validar a associação da regra.                      |
| `version_number`            | inteiro   | Número humano, único por regra e maior que zero.                                            |
| `snapshot`                  | `jsonb`   | Cópia imutável de nome, evento, estado, reentrada, ordem, condições, ações e canvas.       |

Índice único: `(kanban_automation_rule_id, version_number)`.

## Contrato JSON

```json
{
  "nodes": [
    {
      "id": "trigger",
      "type": "trigger",
      "position": { "x": 0, "y": 0 },
      "data": {}
    },
    {
      "id": "wait",
      "type": "delay",
      "position": { "x": 260, "y": 0 },
      "data": { "delay_hours": 24 }
    },
    {
      "id": "message",
      "type": "send_message",
      "position": { "x": 520, "y": 0 },
      "data": {
        "channel": "whatsapp",
        "opt_in_attribute_key": "marketing_messages_opt_in",
        "content": "Olá, {{contact_name}}"
      }
    },
    { "id": "end", "type": "end", "position": { "x": 780, "y": 0 }, "data": {} }
  ],
  "edges": [
    { "id": "trigger-wait", "source": "trigger", "target": "wait" },
    { "id": "wait-message", "source": "wait", "target": "message" },
    { "id": "message-end", "source": "message", "target": "end" }
  ]
}
```

Tipos permitidos na base atual: `trigger`, `delay`, `random_delay`, `wait_until_field`, `wait_for_response`, `wait_for_inactivity`, `wait_for_business_hours`, `stage_guard`, `send_message`, `action`, `set_field`, `update_contact`, `complete_next_action`, `mark_won`, `mark_lost`, `condition`, `filter`, `message_eligibility`, `round_robin`, `human_handoff`, `audit_log`, `webhook`, `end`.

## Catálogo Técnico E Evolução

Todos os nós persistem somente `id`, `type`, `position` e `data`. Ícone, cor, resumo, estado de validação e textos de ajuda são derivados no frontend; não são fonte de verdade no JSON.

| Família | Tipo atual ou planejado | Contrato de `data` | Estado |
| --- | --- | --- | --- |
| Gatilho | `trigger` | evento e filtros compatíveis | atual |
| Gatilho | `scheduled_trigger` | frequência, fuso e critérios de seleção | planejado |
| Tempo | `delay` | duração positiva | atual |
| Tempo | `random_delay` | `min_minutes` e `max_minutes` positivos, com máximo maior ou igual ao mínimo | atual |
| Tempo | `wait_until_field` | campo `date`/`datetime`, deslocamento e fuso | atual |
| Tempo | `wait_for_response` | prazo, política opcional e saídas `received`/`timeout` | atual |
| Tempo | `wait_for_business_hours` | agenda e fuso do board | atual |
| Tempo | `wait_for_inactivity` | prazo e política opcional de interrupção com saídas `inactive`/`responded` | atual |
| Decisão | `condition` | `branches[]`, regras `all`/`any`, `fallback_id` | atual/em consolidação |
| Decisão | `filter` | uma condição e saída de continuação | atual, executado pelo mesmo avaliador do Router |
| Decisão | `message_eligibility` | canal, consentimento, conversa compatível e janela do WhatsApp; saídas `eligible` e `otherwise` | atual |
| Decisão | `round_robin` | opções ordenadas e cursor da regra | atual; rótulo visual `Distribuir caminhos` |
| Decisão | `stage_guard` | usa `conditions.stage_ids` do gatilho | atual; encerra a execução se o card sair da etapa de entrada |
| Cliente | `send_message` | canal, conteúdo/template, opt-in, mídia opcional e política `interromper` ou saídas `Enviada`/`Não enviada` | atual |
| Cliente | `human_handoff` | equipe comercial, responsável e nota opcional; encerra a execução | atual |
| Cliente | `update_contact` | atributo personalizado seguro e valor explícito | atual |
| Oportunidade | `action` | ação comercial e parâmetros autorizados | atual |
| Oportunidade | atualização de campo | definir, incrementar ou limpar um campo configurado | atual |
| Oportunidade | `mark_won` e `mark_lost` | resultado ganho/perdido, motivo configurado na perda | atual |
| Operação | `audit_log` | mensagem interna segura e imutável na linha do tempo | atual |
| Integração | webhook com `failure_mode: route` | mantém retry seguro ou expõe saídas `succeeded` e `failed` | atual |
| Integração | `webhook` | id de conexão aprovada e mapeamento permitido | atual |
| Controle | `end` | resultado terminal opcional | atual/em evolução |

Um novo tipo de nó exige, no mesmo pull request: validação no servidor, semântica de execução/preview, autorização, i18n, renderização do canvas e testes de serviço e componente. O contrato detalhado de cada fase fica no [roadmap do editor](./kanban-visual-workflows-roadmap.md).

## Validação No Servidor

`KanbanAutomations::FlowDefinitionValidator` é chamado pela validação do modelo. Ele deve rejeitar:

- ausência ou multiplicidade de nó `trigger`;
- ids duplicados;
- tipos de nó não permitidos;
- arestas que não apontam para ids existentes;
- espera com horas menores ou iguais a zero;
- intervalo aleatório sem mínimo/máximo positivos ou com máximo menor que o mínimo;
- espera por data sem um campo `date`/`datetime` válido ou ajuste numérico;
- espera por resposta com prazo menor ou igual a zero;
- mensagem sem canal permitido, conteúdo ou chave de opt-in;
- ação fora de `KanbanAutomationRule::ACTION_NAMES`;
- etapa, agente ou campo personalizado que não pertencem ao board ou conta.
- Router sem ao menos uma saída, com id de saída duplicado, regra inválida, conexão sem `sourceHandle` ou sem a rota `fallback_id`;
- webhook sem uma conexão ativa do mesmo board;
- registro interno sem conteúdo;
- atualização de contato que tente usar uma coluna nativa, em vez de um atributo personalizado;
- elegibilidade de mensagem sem canal, opt-in ou as duas conexões obrigatórias;
- ciclos no grafo.

O backend não confia no canvas para validar autorização, referências nem regras de canal.

## Contrato De Governança

Cada execução recebe um snapshot da regra no início. Uma atualização, portanto, não modifica passos já agendados. Na edição, o administrador pode cancelar todas as execuções `waiting`; quando não cancela, elas terminam com o snapshot original. A API expõe uma versão humana, derivada do optimistic locking, e o canvas inicia em rascunho até ser publicado.

Após criar, atualizar ou restaurar a regra, o controlador grava um registro imutável em `kanban_automation_rule_versions`. A restauração só aceita uma versão da própria regra e da mesma conta, aplica o snapshot em transação e grava imediatamente uma nova versão. O frontend exige uma segunda confirmação antes do `POST`; não há restauração silenciosa.

| Conceito           | Regra técnica                                                                                                                                                         |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Reentrada          | Bloqueada enquanto existir execução `queued`, `running` ou `waiting` para a mesma regra e oportunidade. Após conclusão, depende de `reentry_enabled` explícito na regra. |
| Saída/supressão    | Condições são reavaliadas antes de cada nó externo. Se não forem mais satisfeitas, a execução termina como `skipped` com motivo.                                      |
| Webhook de entrada | Endpoint com token de conexão, assinatura HMAC, timestamp curto, idempotency key e `card_id` obrigatório. Não cria oportunidade por efeito colateral.                 |
| Teste guiado       | Resolve variáveis, simula caminho e payload, mas não envia mensagem, webhook nem altera a oportunidade.                                                               |

O sistema não terá nós de código, shell, SQL, acesso a arquivo ou requisição HTTP com URL/credencial digitada pelo usuário.

## Execução

### Disparo

`KanbanCardListener` publica o evento comercial e agenda `KanbanAutomations::ExecuteRuleJob` para cada regra ativa compatível. A execução é criada por `event_key`, com unicidade por regra, para evitar duplicidade.

### Execução Do Grafo

`KanbanAutomations::WorkflowService` inicia no nó salvo em `workflow_state.next_node_id` ou no `trigger`. Em cada nó:

1. `trigger`: segue para a primeira aresta de saída.
2. `delay`: grava `waiting`, `scheduled_at` e o id do próximo nó; agenda `ContinueWorkflowJob`.
3. `random_delay`: sorteia um minuto inteiro inclusivo entre `min_minutes` e `max_minutes`, grava somente o atraso escolhido no histórico e agenda `ContinueWorkflowJob`.
4. `wait_until_field`: agenda a partir de um campo `date` ou `datetime`, com deslocamento em horas. A política padrão interrompe a execução quando a data estiver indisponível; a política `route` exige as saídas `succeeded` e `failed`, registra `date_field_unavailable` e segue pela segunda quando aplicável.
5. `wait_for_response`: grava `waiting_for: customer_message`; uma mensagem recebida retoma o próximo nó, e o prazo encerra a espera pelo job agendado. Com `timeout_mode: route`, a definição exige as saídas `received` e `timeout`; o job escolhe `timeout` somente se o cliente ainda não respondeu sob o lock da execução.
6. `wait_for_inactivity`: grava `waiting_for: customer_inactivity`; o prazo segue a saída normal. Com `interruption_mode: route`, a definição exige `inactive` e `responded`; uma mensagem do cliente troca a continuidade para `responded` sob lock, em vez de apenas ignorar a execução.
7. `wait_for_business_hours`: agenda a próxima data compatível com dias, horário e fuso configurados; dentro da janela, segue imediatamente. Com `failure_mode: route`, exige `succeeded` e `failed` e segue a segunda saída se não puder calcular uma janela futura.
8. `stage_guard`: compara a etapa atual com as etapas selecionadas no gatilho. Sem correspondência, encerra a execução como `skipped: stage_changed`; com correspondência, segue normalmente.
9. `condition`: atua como Router. Avalia suas saídas na ordem salva; cada saída contém condições próprias com modo `all` (E) ou `any` (OU). Segue pela primeira saída verdadeira e, quando nenhuma atende, segue por `fallback_id` (`Caso contrário`). Fluxos legados com `yes` e `no` continuam compatíveis.
10. `action`: delega a `KanbanAutomations::ActionService`.
11. `send_message`: delega a `KanbanAutomations::WorkflowMessageService`.
12. `webhook`: delega a `KanbanAutomations::WebhookDeliveryService`.
13. `end`: conclui a execução.

O limite é de 50 nós por execução. O backend rejeita ciclos. Router e Round Robin têm uma conexão obrigatória por saída, identificada por `sourceHandle`; o Router também exige a conexão da rota padrão. O motor executa uma única ramificação por vez: paralelismo, merge/join e loop não pertencem a este produto.

### Falhas, Retry E Saídas De Erro

Na base atual, uma falha inesperada mantém a execução em estado reprocessável enquanto o Active Job ainda possui tentativas. Apenas ao esgotá-las, `MarkExecutionFailedService` obtém lock, registra `failed`, a mensagem técnica e o horário de conclusão. Para webhook, mensagem e espera até data, o administrador pode optar por `failure_mode: route`: o nó exige uma saída de sucesso e outra de falha, registra apenas um motivo sanitizado (`webhook_delivery_failed`, bloqueio de mensagem ou `date_field_unavailable`) e segue o caminho de falha sem repetir o envio. Espera por resposta e inatividade têm rotas temporais explícitas e mutuamente exclusivas, sempre selecionadas sob lock. Outros nós continuam usando retry do job até terem uma política explícita e idempotente.

Cada passo deve acrescentar um resultado normalizado em `action_results`:

```json
{
  "node_id": "message-1",
  "status": "succeeded",
  "started_at": "2026-07-25T15:00:00Z",
  "finished_at": "2026-07-25T15:00:01Z",
  "summary": "Mensagem WhatsApp enviada",
  "next_node_id": "end"
}
```

Resultados nunca armazenam segredo, payload integral de webhook, token, mensagem de erro de provedor ou dado pessoal desnecessário.

### Retomada

`KanbanAutomations::ContinueWorkflowJob` faz lock na execução, confirma que ela ainda está `waiting` e só retoma se:

- a regra estiver ativa;
- a oportunidade estiver ativa.

Caso contrário, muda para `skipped`, remove `scheduled_at` e encerra. Erros inesperados mudam para `failed`, guardam `error_message` e usam o retry padrão do job.

O endpoint de teste usa `WorkflowPreviewService`, que percorre os nós e devolve passos planejados sem chamar `ActionService` ou criar mensagens. Para o nó de mensagem, ele resolve as variáveis do contato, oportunidade, valor e campos personalizados com o mesmo renderizador do envio. Na interface, o administrador escolhe uma oportunidade ativa do board, vê se as condições são atendidas e recebe a sequência traduzida dos passos previstos; o teste pode ser aberto tanto na lista quanto no cabeçalho de uma regra já salva. Mensagens, webhooks e ações internas nunca são disparados. Uma execução em estado `waiting` pode ser cancelada individualmente; ela passa para `skipped`, limpa `scheduled_at` e registra o motivo no histórico. A lista de execuções mostra por passo a ação, saída, estado e horário; a API limita esse histórico a metadados permitidos e nunca devolve payloads, conversas ou segredos de integrações.

## Nó De Mensagem

`WorkflowMessageService` encontra a conversa mais recente do contato no canal solicitado.

| Condição                   | Resultado                                                               |
| -------------------------- | ----------------------------------------------------------------------- |
| Não há conversa compatível | `skipped: no_compatible_conversation`                                   |
| Opt-in falso ou ausente    | `skipped: opt_in_required`                                              |
| WhatsApp fora da janela    | `skipped: outside_whatsapp_window`                                      |
| Horário silencioso         | `waiting: quiet_hours`, retomada no horário configurado                 |
| Intervalo mínimo ativo     | `waiting: frequency_limit`, retomada após a última mensagem de workflow |
| Envio aceito               | `succeeded` com `message_id`                                            |

O conteúdo substitui somente variáveis permitidas: `{{contact_name}}`, `{{opportunity_subject}}`, `{{opportunity_amount}}` e `{{field.<chave_do_campo>}}`. Token desconhecido permanece literal. O nó pode receber `frequency_limit_hours` (até 720 horas), `quiet_hours` com `start`, `end` e `timezone`, `whatsapp_template_params` para mensagem oficial e `message_attachment_signed_id` de uma imagem do Active Storage validada pelo backend.

## Nó De Ação

O nó utiliza o mesmo serviço das regras comerciais legadas. Ações aceitas:

- `move_stage`: exige `action_params.stage_id` do board;
- `assign_owner`: recebe `action_params.owner_id` da conta, ou vazio para remover responsável;
- `assign_round_robin`: recebe `action_params.owner_ids` em ordem; o cursor da regra é atualizado sob lock para distribuir execuções concorrentes sem repetir indevidamente o agente;
- `set_next_action`: aceita tipo, data/hora e observação;
- `set_field`: exige chave de campo existente e valor;
- `increment_field`: exige campo personalizado numérico e incremento finito;
- `clear_field`: exige chave de campo existente e remove somente o valor daquela chave;
- `update_contact`: aceita somente atributo personalizado com chave segura. `date_of_birth` exige data ISO (`YYYY-MM-DD`) e os consentimentos de marketing, aniversário e lembrete de consulta são normalizados para booleano; outros atributos permanecem valores explícitos configurados pelo gestor;
- `complete_next_action`: conclui a atividade atual e pode registrar `completion_note` no histórico. Quando `schedule_next_action` está ativo, exige juntos `next_action_type` e uma data/hora válida em `next_action_at`, com observação opcional, para abrir a próxima atividade sem perder a concluída; a validação ocorre antes de alterar a atividade atual;
- `archive_card`: não requer parâmetro.
- `add_label` e `remove_label`: exigem `action_params.label` não vazio.
- `add_note`: exige `action_params.content` e uma conversa vinculada; cria uma mensagem privada, nunca uma mensagem ao cliente.

## Nó De Webhook

O nó escolhe uma conexão ativa do mesmo board. O backend envia `POST` JSON com oportunidade, contato, conversa, regra e execução. Ele usa timeout de abertura de 3 segundos, leitura de 10 segundos e `max_redirects: 0`.

Cabeçalhos enviados:

- `X-Chatwoot-Event`
- `X-Chatwoot-Delivery` e `X-Chatwoot-Idempotency-Key`, no formato `kanban-<execution_id>-<node_id>`
- `X-Chatwoot-Timestamp`
- `X-Chatwoot-Signature: sha256=<hex>`, calculado sobre `<timestamp>.<body>` com a chave da conexão.

O segredo só é retornado na criação ou na regeneração. Falhas HTTP, TLS ou rede tornam a execução `failed`; resultado e logs guardam apenas status, conexão e código HTTP, sem payload ou segredo.

## Webhook De Entrada

Cada conexão também expõe `POST /webhooks/kanban/:inbound_token`. O consumidor envia JSON com `card_id` e os cabeçalhos `X-Chatwoot-Timestamp`, `X-Chatwoot-Idempotency-Key` e `X-Chatwoot-Signature`. A assinatura é HMAC SHA-256 de `<timestamp>.<body>` com a chave da conexão.

O timestamp deve estar a no máximo cinco minutos do servidor. A chave de idempotência é obrigatória e se torna o `event_key` da execução. O endpoint só aceita a oportunidade ativa do board da conexão e inicia regras ativas de `kanban.card.webhook_received`; regras com `connection_ids` só iniciam pela conexão correspondente. Campos extras do JSON não são interpretados como ações. Assinatura, token, timestamp ou card inválidos não expõem detalhes internos.

## API

Os endpoints existentes de regras recebem e devolvem `flow_definition`:

- `GET /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules`
- `PATCH /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id`
- `GET /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/executions`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id/run`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id/executions/:execution_id/retry`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id/executions/:execution_id/cancel`
- `GET /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id/versions`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id/versions/:version_id/restore`
- `GET|POST|PATCH|DELETE /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_connections`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_connections/:id/reset_secret`

Erros de validação respondem `422` com `message` e `errors`. O frontend deve mostrar o erro sem limpar o canvas do usuário; quando a mensagem identifica um `node_id`, deve selecionar, destacar e abrir esse nó.

## Frontend

### Contrato Visual Do Workspace

O workspace é uma fusão de cinco referências funcionais: Chatwoot para tokens e integração nativa, Frappe CRM para densidade operacional, Kommo para linguagem comercial e progressão, Node-RED para descoberta de blocos e n8n apenas como referência de comportamento do canvas e inspector. Não é permitido copiar código, componentes ou aparência proprietária de nenhuma referência.

O layout desktop do editor tem três camadas: paleta lateral operacional fixa em `12.25rem` (196 px), canvas flexível com altura mínima de `42rem` e diálogo contextual sobreposto de até `44rem` (704 px). A paleta nunca cresce com o conteúdo dos blocos; o cabeçalho exibe busca e contagem total, as categorias são recolhíveis, apresentam sua própria contagem, preservam a escolha de abertura após nova renderização e seus itens têm ícone em bloco, título truncável e área de clique/arraste estável. O diálogo é `fixed`, centralizado sobre o canvas e tem altura limitada ao viewport; ele abre como configuração contextual, nunca como coluna permanente nem drawer alto em desktop. Em telas pequenas, ele ocupa a viewport com margens seguras.

`KanbanWorkflowNode` usa largura estável de `9.5rem` (152 px) e não pode renderizar formulários, condições completas ou múltiplas linhas de chips no canvas. O card mostra, no máximo, categoria, ícone, título, resumo curto, estado e os indicadores indispensáveis para compreender a rota. As regras completas pertencem ao inspector. Cada saída continua com rótulo, handle e inserção contextual acessível. Ao selecionar uma aresta, o inspector resolve e mostra o resumo `origem → destino`, evitando o rótulo técnico genérico de conexão selecionada.

O toolbar do canvas agrupa desfazer, refazer, organizar e inserir em um único bloco identificado por `data-testid="kanban-workflow-canvas-toolbar"`. Ações de configuração, teste e histórico pertencem ao diálogo do elemento selecionado. O diálogo preserva foco, fecha por Escape, devolve foco ao editor e usa título ligado por `aria-labelledby`. Seu cabeçalho apresenta categoria, título e estado do nó; a navegação é uma grade de três abas com ícones e `data-testid="kanban-workflow-inspector-tabs"`. As abas implementam roving tabindex e respondem a setas, Home e End, preservando o foco no item ativado. Escape também fecha os seletores de criação de desktop e mobile sem alterar o fluxo.

A faixa de configuração imediata é identificada por `data-testid="kanban-automation-editor-header"`, tem altura mínima de `54px` no desktop e mantém nome, resumo do gatilho, opções avançadas, estado de publicação, validar, testar, cancelar e salvar antes do canvas. Ela é a única barra do fluxo: o cabeçalho geral da central não é renderizado enquanto o editor está aberto. Critérios compatíveis ficam em popover contextual; reentrada, cancelamento de esperas e condição posterior permanecem recolhidos. Em telas pequenas, os controles quebram em linhas sem comprimir o editor. Modelos e regras existentes usam cartões compactos com ícone semântico, título truncável, informação secundária e ação explícita de editar; teste e versões seguem como ações adjacentes de menor ênfase.

`KanbanAutomations.vue` é a central dedicada do board, disponível em `/app/accounts/:accountId/kanban/:boardId/automations`. Ela carrega configuração, regras, lembretes, conexões e execuções. A aba Fluxos lista regras, oferece modelos em rascunho e abre o editor dedicado; Conexões cria URLs assinadas sem colocar segredos no canvas; Execuções permite diagnóstico, retry de falhas e cancelamento de esperas. Cadências existentes são legadas e não aparecem como opção no novo editor.

Cada criação, atualização ou restauração registra um snapshot imutável em `kanban_automation_rule_versions`. O histórico é acessado pelo ícone de relógio na regra. Restaurar uma versão pede confirmação contextual, gera uma nova versão e só muda inscrições futuras: `KanbanAutomationExecution#automation_snapshot` continua sendo a fonte de verdade para execuções já iniciadas.

`KanbanWorkflowBuilder.vue` recebe `modelValue`, etapas, agentes, campos personalizados e tipos de próxima ação. Ele emite somente nós persistíveis, removendo metadados de apresentação como rótulo, resumo e estado de validação. `KanbanWorkflowPalette.vue` é o catálogo visual independente: agrupa tipos por categoria, filtra por texto e emite a escolha por clique ou início de arraste. O builder converte o ponto de drop por `screenToFlowCoordinate`, preserva a alternativa por clique e insere o nó no canvas. Em viewport menor que `lg`, o controle `data-testid="kanban-workflow-open-mobile-palette"` substitui o seletor compacto de desktop e abre a paleta no drawer; Escape o fecha sem alterar o canvas e devolve foco ao controle que o abriu.

O editor deve evoluir para estes componentes, sem concentrar todo o estado em um arquivo de tela:

| Componente/serviço | Responsabilidade |
| --- | --- |
| `KanbanWorkflowPalette` | Busca, categorias, favoritos futuros e inserção por clique/arraste. |
| `KanbanWorkflowCanvas` | Vue Flow, seleção, viewport, minimapa, controles e eventos de canvas. |
| `KanbanWorkflowNode` | Casca visual comum: categoria, ícone, título, resumo, chips, handles e estado. |
| `KanbanWorkflowEdge` | Rótulo de saída, foco, inserção contextual e remoção acessível. |
| `KanbanWorkflowInspector` | Diálogo flutuante com `Configurar`, `Testar` e `Histórico`. |
| Inspectores por família | Configuração progressiva de Tempo, Decisão, Distribuir caminhos e Utilitários; Mensagem, Contato e Ações comerciais seguem como próximas extrações. |
| `useKanbanWorkflowCanvas` | Criar, mover, conectar, remover, inserir, desfazer/refazer e auto-organizar. |
| `nodeDefinitions` | Registro único de tipos, categoria, ícone, schema local, resumo e ajuda. |

`nodeDefinitions` não substitui a validação Rails. Ele reduz erros antes do salvamento e garante que paleta, canvas, inspector e preview usem a mesma linguagem comercial.

O canvas preserva a maior parte da largura. Clicar em nó ou conexão abre um diálogo flutuante sobreposto, sem reduzir a área do fluxo. O menu `+` existe como alternativa compacta em telas pequenas e para inserir diretamente após um conector; ele não substitui a paleta. A configuração contextual e o histórico de execução não são colunas permanentes.

O diálogo configura o nó selecionado e usa o nome do nó na sua abertura. Antes das abas, ele mostra um resumo comercial curto da etapa selecionada; o bloco de ícone herda a cor semântica da categoria do nó para manter a relação imediata com o canvas. O formulário completo continua dentro da aba Configurar. O nó de mensagem oferece emoji, busca de variáveis, imagem de até 10 MB, preview e remoção da mídia. O upload persiste somente o `signed_id` do Active Storage e o backend aceita exclusivamente blobs de imagem válidos. A mesma estrutura de mensagem está disponível na automação anual de aniversário. Quando a validação local encontra um nó inválido, ele é destacado, selecionado e aberto para correção. O canvas tem zoom e controles, mas a edição do evento e das condições permanece no formulário da regra comercial para evitar duplicação de fontes de verdade. A paleta permanece recolhível e pesquisável; o canvas é sempre a superfície dominante e o histórico só é mostrado por solicitação.

O diálogo deve aceitar todos os formulários de nó e conexão. Em desktop, sua largura é `min(44rem, calc(100vw - 4rem))`; em mobile usa `inset` de `1rem`. Formulários longos usam rolagem vertical sem overflow horizontal, enquanto cabeçalho e abas permanecem visíveis. O contêiner tem `role="dialog"`, `aria-modal="true"`, nome programático pelo título real do elemento e focus trap por Tab/Shift+Tab. Fechar por Escape, botão ou fundo restaura o foco no elemento de origem; alterações continuam no rascunho da regra até salvar ou cancelar.

Para fluxos maiores, o minimapa só deve ser exibido quando o conteúdo extrapolar a área visível. Controles devem ter rótulo acessível, foco visível e uma alternativa sem arrastar: selecionar um nó, usar o inseridor `+` e escolher o próximo passo pelo teclado. Paleta, canvas, arestas e diálogo devem ter ordem de foco previsível; Escape fecha o diálogo e devolve foco ao nó ou à aresta que o abriu.

O nó `Aguardar até data` armazena o fuso da data. Valores locais de campos `date` e `datetime` são interpretados nesse fuso antes de aplicar o ajuste em horas; fluxos antigos sem fuso continuam usando o fuso global do Rails para preservar o comportamento existente.

### Auditoria de conexões

Cada criação, alteração, remoção ou regeneração de segredo de uma conexão aprovada gera um evento administrativo associado à conta, quadro e usuário executor. O evento persiste apenas a ação, os nomes dos atributos alterados e, na remoção, o nome legível da conexão; URL, segredo, token de entrada e payload externo nunca são armazenados nem retornados pela API de auditoria. A aba de Integrações exibe os últimos eventos com hora local do navegador.

## Segurança E Auditoria

- Não há execução de código definido pelo usuário.
- Não há credenciais no JSON do fluxo.
- Mensagens externas obedecem opt-in e política do canal.
- Cada nó acrescenta resultado em `action_results`, com `node_id`, resultado e motivo quando ignorado.
- Segredos, tokens e conteúdo de erro de provedores não devem ser gravados em `action_results` ou logs.
- Webhooks externos usam `SsrfFilter`, HTTPS, bloqueio de credenciais na URL e não seguem redirecionamentos.

## Testes Mínimos

- validação de nó desconhecido, mensagem incompleta e referência inválida;
- criação e atualização via API com `flow_definition`;
- pausa, persistência de estado e retomada;
- desativação da regra durante espera;
- ação interna e mensagem sem conversa compatível;
- renderização do canvas, painel de ações e abas de conexão/execução;
- assinatura HMAC, chave única na criação e bloqueio de URL não HTTPS;
- retomada da espera quando o cliente responde;
- navegação por teclado, foco e responsividade devem entrar na suíte E2E antes de P2.
- duas edições concorrentes da mesma oportunidade e reexecução idempotente de webhook;
- alteração/desativação de regra com execuções aguardando, nas opções manter e cancelar;
- criação, listagem e restauração de versões; incluindo rejeição de versão pertencente a outra regra ou conta;
- execução de fluxo longo, volume alto de cards e fuso horário de espera por data.

## Migrations E Deploy

Aplicar as migrations de fluxos, conexões e versões uma única vez, no container `chatwoot_api`:

```sh
bundle exec rails db:migrate
```

O `chatwoot_sidekiq` deve usar a mesma imagem para consumir `ContinueWorkflowJob`.

### Smoke seguro pós-deploy

Execute o smoke somente depois de atualizar `chatwoot_api` e `chatwoot_sidekiq` para a mesma tag da imagem. Ele verifica a estrutura e o carregamento das classes, mas não publica regras nem dispara mensagens:

```sh
API_ID=$(docker ps --filter name=chatwoot_api --format '{{.ID}}' | head -n 1)
SIDEKIQ_ID=$(docker ps --filter name=chatwoot_sidekiq --format '{{.ID}}' | head -n 1)

docker exec -it "$API_ID" sh -lc 'bundle exec rails db:migrate'
docker exec -it "$API_ID" sh -lc 'bundle exec rake kanban_automations:smoke'
docker exec -it "$SIDEKIQ_ID" sh -lc 'bundle exec rake kanban_automations:smoke'
```

O primeiro comando deve concluir sem migration pendente; os dois seguintes devem terminar com `Kanban automations smoke passed`. A tarefa confirma o índice parcial de próximas ações vencidas, a tabela de auditoria e as classes de execução em ambos os containers, sem criar ou modificar dados. No dashboard, valide então um rascunho com `Aguardar por data` configurado para `Criar rota de falha`, conectando `Data disponível` e `Data indisponível` por meio do inspector. Publique apenas uma regra de teste, com um contato de teste e sem nó de mensagem, antes de habilitar automações comerciais reais.

As cadências legadas acionadas pela entrada em etapa consultam todas as cadências ativas daquela etapa. A inscrição é única por oportunidade e cadência; em concorrência, a tentativa que perde a criação recupera a inscrição criada pelo outro worker, sem duplicar follow-ups.

### E2E De Homologação

Com uma conta de teste, um quadro ativo e ao menos uma oportunidade de teste, execute a suíte visual contra a URL da homologação. `KANBAN_E2E_BOARD_ID` é opcional, mas recomenda-se defini-lo quando a conta possuir mais de um quadro visível para que a execução não dependa da ordenação da tela inicial.

```sh
cd tests/playwright
BASE_URL=https://chatwt.exemplo.com.br \
TEST_USER_EMAIL=qa@example.com \
TEST_USER_PASSWORD='senha-de-teste' \
KANBAN_E2E=1 \
KANBAN_E2E_BOARD_ID=42 \
npx playwright test tests/e2e/ui/kanban-accessibility.spec.ts
```

O cenário executa em desktop e mobile, incluindo viewport de 320 px, abertura e fechamento do drawer de oportunidade, paleta do workflow, inspector e ciclo de foco por Tab. As credenciais devem pertencer a uma conta de teste e nunca a um usuário operacional.

Em desenvolvimento local, use uma conta exclusiva de E2E com acesso administrativo ao quadro e entre pela rota `/app/login`. O helper da suíte aguarda apenas o commit da navegação: a disponibilidade dos elementos é verificada pelos próprios cenários, evitando que a recompilação incremental do Vite seja tratada como uma falha de login.
