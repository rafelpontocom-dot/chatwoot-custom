# Spec: Fluxos Visuais Do Kanban

## Escopo Técnico

O construtor é implementado em Vue 3 com `@vue-flow/core`, `@vue-flow/background` e `@vue-flow/controls`. O canvas persiste sua definição em `KanbanAutomationRule.flow_definition`; a execução usa Sidekiq e PostgreSQL.

## Persistência

### `kanban_automation_rules`

| Campo | Tipo | Uso |
| --- | --- | --- |
| `flow_definition` | `jsonb`, obrigatório, padrão `{}` | Nós, arestas, posições e configuração de cada nó. |

Uma regra sem `flow_definition.nodes` continua usando o formato legado `actions`.

### `kanban_automation_executions`

| Campo | Tipo | Uso |
| --- | --- | --- |
| `workflow_state` | `jsonb`, obrigatório, padrão `{}` | Próximo nó a executar durante uma espera. |
| `scheduled_at` | `datetime` | Quando `ContinueWorkflowJob` deve retomar a execução. |
| `status` | enum string | `queued`, `running`, `waiting`, `succeeded`, `failed`, `skipped`. |

Índice: `(status, scheduled_at)` para diagnóstico e consultas de execuções aguardando.

## Contrato JSON

```json
{
  "nodes": [
    { "id": "trigger", "type": "trigger", "position": { "x": 0, "y": 0 }, "data": {} },
    { "id": "wait", "type": "delay", "position": { "x": 260, "y": 0 }, "data": { "delay_hours": 24 } },
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

Tipos permitidos: `trigger`, `delay`, `wait_until_field`, `send_message`, `action`, `condition`, `end`.

## Validação No Servidor

`KanbanAutomations::FlowDefinitionValidator` é chamado pela validação do modelo. Ele deve rejeitar:

- ausência ou multiplicidade de nó `trigger`;
- ids duplicados;
- tipos de nó não permitidos;
- arestas que não apontam para ids existentes;
- espera com horas menores ou iguais a zero;
- espera por data sem um campo `date`/`datetime` válido ou ajuste numérico;
- mensagem sem canal permitido, conteúdo ou chave de opt-in;
- ação fora de `KanbanAutomationRule::ACTION_NAMES`;
- etapa, agente ou campo personalizados que não pertencem ao board ou conta.
- condição sem saídas `yes` e `no`;
- ciclos no grafo.

O backend não confia no canvas para validar autorização, referências nem regras de canal.

## Execução

### Disparo

`KanbanCardListener` publica o evento comercial e agenda `KanbanAutomations::ExecuteRuleJob` para cada regra ativa compatível. A execução é criada por `event_key`, com unicidade por regra, para evitar duplicidade.

### Caminho Linear

`KanbanAutomations::WorkflowService` inicia no nó salvo em `workflow_state.next_node_id` ou no `trigger`. Em cada nó:

1. `trigger`: segue para a primeira aresta de saída.
2. `delay`: grava `waiting`, `scheduled_at` e o id do próximo nó; agenda `ContinueWorkflowJob`.
3. `wait_until_field`: agenda a partir de um campo `date` ou `datetime`, com deslocamento em horas.
4. `condition`: avalia um campo e segue pela saída `yes` ou `no`.
5. `action`: delega a `KanbanAutomations::ActionService`.
6. `send_message`: delega a `KanbanAutomations::WorkflowMessageService`.
7. `end`: conclui a execução.

O limite é de 50 nós por execução. O backend rejeita ciclos; o único nó com duas saídas é `condition`, identificado por `sourceHandle: yes` e `sourceHandle: no`.

### Retomada

`KanbanAutomations::ContinueWorkflowJob` faz lock na execução, confirma que ela ainda está `waiting` e só retoma se:

- a regra estiver ativa;
- a oportunidade estiver ativa.

Caso contrário, muda para `skipped`, remove `scheduled_at` e encerra. Erros inesperados mudam para `failed`, guardam `error_message` e usam o retry padrão do job.

O endpoint de teste usa `WorkflowPreviewService`, que percorre os nós e devolve passos planejados sem chamar `ActionService` ou `WorkflowMessageService`. Uma execução em estado `waiting` pode ser cancelada individualmente; ela passa para `skipped`, limpa `scheduled_at` e registra o motivo no histórico.

## Nó De Mensagem

`WorkflowMessageService` encontra a conversa mais recente do contato no canal solicitado.

| Condição | Resultado |
| --- | --- |
| Não há conversa compatível | `skipped: no_compatible_conversation` |
| Opt-in falso ou ausente | `skipped: opt_in_required` |
| WhatsApp fora da janela | `skipped: outside_whatsapp_window` |
| Envio aceito | `succeeded` com `message_id` |

O conteúdo substitui somente `{{contact_name}}`. Novas variáveis exigem lista permitida e testes próprios.

## Nó De Ação

O nó utiliza o mesmo serviço das regras comerciais legadas. Ações aceitas:

- `move_stage`: exige `action_params.stage_id` do board;
- `assign_owner`: recebe `action_params.owner_id` da conta, ou vazio para remover responsável;
- `set_next_action`: aceita tipo, data/hora e observação;
- `set_field`: exige chave de campo existente e valor;
- `archive_card`: não requer parâmetro.

## API

Os endpoints existentes de regras recebem e devolvem `flow_definition`:

- `GET /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules`
- `POST /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules`
- `PATCH /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/automation_rules/:id`

Erros de validação respondem `422` com `message` e `errors`. O frontend deve mostrar o erro sem limpar o canvas do usuário.

## Frontend

`KanbanWorkflowBuilder.vue` recebe `modelValue`, etapas, agentes, campos personalizados e tipos de próxima ação. Ele emite somente nós persistíveis, removendo metadados de apresentação como rótulo e resumo.

O painel lateral configura o nó selecionado. O canvas tem zoom e controles, mas a edição do evento e das condições permanece no formulário da regra comercial para evitar duplicação de fontes de verdade.

## Segurança E Auditoria

- Não há execução de código definido pelo usuário.
- Não há credenciais no JSON do fluxo.
- Mensagens externas obedecem opt-in e política do canal.
- Cada nó acrescenta resultado em `action_results`, com `node_id`, resultado e motivo quando ignorado.
- Segredos, tokens e conteúdo de erro de provedores não devem ser gravados em `action_results` ou logs.

## Testes Mínimos

- validação de nó desconhecido, mensagem incompleta e referência inválida;
- criação e atualização via API com `flow_definition`;
- pausa, persistência de estado e retomada;
- desativação da regra durante espera;
- ação interna e mensagem sem conversa compatível;
- renderização do canvas e do painel de ações;
- navegação por teclado, foco e responsividade devem entrar na suíte E2E antes de P2.

## Migrations E Deploy

Aplicar `20260731100000_add_visual_flow_to_kanban_automations.rb` uma única vez, no container `chatwoot_api`:

```sh
bundle exec rails db:migrate
```

O `chatwoot_sidekiq` deve usar a mesma imagem para consumir `ContinueWorkflowJob`.
