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

Índice: `(status, scheduled_at)` para diagnóstico e consultas de execuções aguardando.

### `kanban_automation_connections`

| Campo           | Tipo            | Uso                                                                  |
| --------------- | --------------- | -------------------------------------------------------------------- |
| `name`          | string          | Nome legível, único por funil.                                       |
| `webhook_url`   | string          | Endpoint HTTPS sem credenciais embutidas.                            |
| `secret`        | texto protegido | Chave para assinatura HMAC SHA-256. Nunca retorna nas listagens.     |
| `active`        | boolean         | Uma conexão inativa não pode ser escolhida por um nó.                |
| `inbound_token` | string secreta  | Identifica o endpoint de entrada e nunca dispensa a assinatura HMAC. |

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

Tipos permitidos: `trigger`, `delay`, `wait_until_field`, `wait_for_response`, `send_message`, `action`, `condition`, `webhook`, `end`.

## Validação No Servidor

`KanbanAutomations::FlowDefinitionValidator` é chamado pela validação do modelo. Ele deve rejeitar:

- ausência ou multiplicidade de nó `trigger`;
- ids duplicados;
- tipos de nó não permitidos;
- arestas que não apontam para ids existentes;
- espera com horas menores ou iguais a zero;
- espera por data sem um campo `date`/`datetime` válido ou ajuste numérico;
- espera por resposta com prazo menor ou igual a zero;
- mensagem sem canal permitido, conteúdo ou chave de opt-in;
- ação fora de `KanbanAutomationRule::ACTION_NAMES`;
- etapa, agente ou campo personalizado que não pertencem ao board ou conta.
- condição sem saídas `yes` e `no`;
- webhook sem uma conexão ativa do mesmo board;
- ciclos no grafo.

O backend não confia no canvas para validar autorização, referências nem regras de canal.

## Contrato De Governança Planejado

Antes de habilitar reentrada ampla, a regra passará a ter uma versão publicada imutável para cada execução. A edição permanecerá em rascunho; publicar cria uma versão e solicita o destino das execuções `waiting` da versão anterior: manter até o fim ou cancelar.

| Conceito           | Regra técnica                                                                                                                                                         |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Reentrada          | Bloqueada enquanto existir execução `queued`, `running` ou `waiting` para a mesma regra e oportunidade. Após conclusão, depende de configuração explícita do gatilho. |
| Saída/supressão    | Condições são reavaliadas antes de cada nó externo. Se não forem mais satisfeitas, a execução termina como `skipped` com motivo.                                      |
| Webhook de entrada | Endpoint com token de conexão, assinatura HMAC, timestamp curto, idempotency key e `card_id` obrigatório. Não cria oportunidade por efeito colateral.                 |
| Teste guiado       | Resolve variáveis, simula caminho e payload, mas não envia mensagem, webhook nem altera a oportunidade.                                                               |

O sistema não terá nós de código, shell, SQL, acesso a arquivo ou requisição HTTP com URL/credencial digitada pelo usuário.

## Execução

### Disparo

`KanbanCardListener` publica o evento comercial e agenda `KanbanAutomations::ExecuteRuleJob` para cada regra ativa compatível. A execução é criada por `event_key`, com unicidade por regra, para evitar duplicidade.

### Caminho Linear

`KanbanAutomations::WorkflowService` inicia no nó salvo em `workflow_state.next_node_id` ou no `trigger`. Em cada nó:

1. `trigger`: segue para a primeira aresta de saída.
2. `delay`: grava `waiting`, `scheduled_at` e o id do próximo nó; agenda `ContinueWorkflowJob`.
3. `wait_until_field`: agenda a partir de um campo `date` ou `datetime`, com deslocamento em horas.
4. `wait_for_response`: grava `waiting_for: customer_message`; uma mensagem recebida retoma o próximo nó, e o prazo encerra a espera pelo job agendado.
5. `condition`: avalia um campo e segue pela saída `yes` ou `no`.
6. `action`: delega a `KanbanAutomations::ActionService`.
7. `send_message`: delega a `KanbanAutomations::WorkflowMessageService`.
8. `webhook`: delega a `KanbanAutomations::WebhookDeliveryService`.
9. `end`: conclui a execução.

O limite é de 50 nós por execução. O backend rejeita ciclos; o único nó com duas saídas é `condition`, identificado por `sourceHandle: yes` e `sourceHandle: no`.

### Retomada

`KanbanAutomations::ContinueWorkflowJob` faz lock na execução, confirma que ela ainda está `waiting` e só retoma se:

- a regra estiver ativa;
- a oportunidade estiver ativa.

Caso contrário, muda para `skipped`, remove `scheduled_at` e encerra. Erros inesperados mudam para `failed`, guardam `error_message` e usam o retry padrão do job.

O endpoint de teste usa `WorkflowPreviewService`, que percorre os nós e devolve passos planejados sem chamar `ActionService` ou `WorkflowMessageService`. Uma execução em estado `waiting` pode ser cancelada individualmente; ela passa para `skipped`, limpa `scheduled_at` e registra o motivo no histórico.

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

O conteúdo substitui somente `{{contact_name}}`. O nó pode receber `frequency_limit_hours` (até 720 horas) e `quiet_hours` com `start`, `end` e `timezone`. Novas variáveis exigem lista permitida e testes próprios.

## Nó De Ação

O nó utiliza o mesmo serviço das regras comerciais legadas. Ações aceitas:

- `move_stage`: exige `action_params.stage_id` do board;
- `assign_owner`: recebe `action_params.owner_id` da conta, ou vazio para remover responsável;
- `set_next_action`: aceita tipo, data/hora e observação;
- `set_field`: exige chave de campo existente e valor;
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

O timestamp deve estar a no máximo cinco minutos do servidor. A chave de idempotência é obrigatória e se torna o `event_key` da execução. O endpoint só aceita a oportunidade ativa do board da conexão e inicia regras ativas de `kanban.card.webhook_received`; campos extras do JSON não são interpretados como ações. Assinatura, token, timestamp ou card inválidos não expõem detalhes internos.

## API

Os endpoints existentes de regras recebem e devolvem `flow_definition`:

- `GET /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules`
- `PATCH /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id`
- `GET /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/executions`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id/run`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id/executions/:execution_id/retry`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id/executions/:execution_id/cancel`
- `GET|POST|PATCH|DELETE /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_connections`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_connections/:id/reset_secret`

Erros de validação respondem `422` com `message` e `errors`. O frontend deve mostrar o erro sem limpar o canvas do usuário.

## Frontend

`KanbanAutomations.vue` é a central dedicada do board, disponível em `/app/accounts/:accountId/kanban/:boardId/automations`. Ela carrega configuração, regras, lembretes, conexões e execuções. A aba Fluxos lista regras, oferece modelos em rascunho e abre o editor dedicado; Conexões cria URLs assinadas sem colocar segredos no canvas; Execuções permite diagnóstico, retry de falhas e cancelamento de esperas. Cadências existentes são legadas e não aparecem como opção no novo editor.

`KanbanWorkflowBuilder.vue` recebe `modelValue`, etapas, agentes, campos personalizados e tipos de próxima ação. Ele emite somente nós persistíveis, removendo metadados de apresentação como rótulo e resumo. A inserção de nós é acionada por um único botão `+`, que abre um menu de tipos. O canvas e o painel de propriedades permanecem lado a lado em telas largas e empilham em telas menores.

O painel lateral configura o nó selecionado. O canvas tem zoom e controles, mas a edição do evento e das condições permanece no formulário da regra comercial para evitar duplicação de fontes de verdade.

Para fluxos maiores, o minimapa só deve ser exibido quando o conteúdo extrapolar a área visível. Controles devem ter rótulo acessível, foco visível e uma alternativa sem arrastar: selecionar um nó, usar o inseridor `+` e escolher o próximo passo pelo teclado.

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
- execução de fluxo longo, volume alto de cards e fuso horário de espera por data.

## Migrations E Deploy

Aplicar as migrations de fluxos e conexões uma única vez, no container `chatwoot_api`:

```sh
bundle exec rails db:migrate
```

O `chatwoot_sidekiq` deve usar a mesma imagem para consumir `ContinueWorkflowJob`.
