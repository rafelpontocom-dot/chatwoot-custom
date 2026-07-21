# Spec: Kanban Comercial Personalizavel

Baseado em: [PRD: Kanban Comercial no Chatwoot](./kanban-sales-prd.md)

Status: especificação implementada e coberta por testes automatizados

## Objetivo Da Spec

Transformar o PRD em comportamento implementável, preservando o Kanban atual e evoluindo-o para venda.

Esta spec evita decisões que acoplem o produto a consulta, reunião ou qualquer ciclo comercial específico.

## Entidades

### KanbanBoard

Representa um funil comercial.

Campos existentes relevantes:

- `name`
- `description`
- `visibility_mode`
- `inbox_scope_mode`
- `auto_create_cards_from_conversations`
- `next_action_types`: lista configurável de tipos de próxima ação;
- `lost_reason_options`: lista configurável de motivos de perda;

Campos comerciais implementados:

- `custom_field_definitions`: definição dos campos personalizados do board;
- `compact_card_field_keys`: campos customizados exibidos no card compacto;
- `stale_stage_thresholds`: limites por etapa para alerta de card parado.

### KanbanStage

Representa etapa comercial.

Campos existentes relevantes:

- `name`
- `position`
- `color`
- `active`

Campos futuros sugeridos:

- `category`: `open`, `won`, `lost`;
- `requires_next_action`: boolean;
- `stale_after_hours`: inteiro opcional.

### KanbanCard

Representa oportunidade comercial.

Campos existentes relevantes:

- `account_id`
- `kanban_board_id`
- `kanban_stage_id`
- `contact_id`
- `conversation_id`
- `inbox_id`
- `subject`
- `description`
- `starts_at`
- `due_at`
- `stage_entered_at`
- `origin`
- `position`
- `active`

Campos comerciais implementados:

- `owner_id`: responsável comercial, quando diferente do responsável da conversa;
- `next_action_type`;
- `next_action_at`;
- `next_action_note`;
- `next_action_completed_at`;
- `won_at`;
- `lost_at`;
- `lost_reason`;
- `closed_by_id`;
- `amount_cents`;
- `amount_currency`;
- `custom_field_values`;
- `next_action_history`: últimas ações concluídas, limitado a 100 registros;

Campos futuros:

- `custom_field_audit_events`: histórico de alterações dos campos comerciais;
- `last_next_action_completed_by_id`;
- `last_next_action_completed_at`.

## Estados Do Card

Um card pode estar:

- aberto;
- ganho;
- perdido;
- inativo/removido.

Derivados visuais:

- sem próximo passo;
- próximo passo futuro;
- próximo passo hoje;
- próximo passo atrasado;
- parado na etapa;
- fechado.

## Regras De Negocio

### Oportunidade Aberta

Um card aberto é qualquer card ativo que não está ganho nem perdido.

Regra:

- card aberto deve ter etapa e responsável comercial;
- card aberto deve poder ter próximo passo;
- se o board exigir próximo passo, card aberto sem `next_action_at` fica destacado.

### Proxima Acao

`next_action_at` define quando o vendedor precisa agir.

`next_action_type` deve vir das opções configuradas no board. Se o board não tiver opções salvas, o backend expõe a lista padrão.

Ao salvar a configuração do board, valores vazios devem ser ignorados e valores duplicados devem ser removidos.

Se `next_action_at` for anterior ao início do dia atual, o card é atrasado.

Se `next_action_at` estiver no dia atual, o card é de hoje.

Se `next_action_at` estiver no futuro, o card é futuro.

Se `next_action_at` estiver vazio e o card estiver aberto, o card é sem próximo passo.

### Ganho

Ao marcar como ganho:

- preencher `won_at`;
- limpar `lost_at`;
- limpar `lost_reason`;
- preencher `closed_by_id`;
- opcionalmente mover para etapa de categoria `won`, se existir.

### Perdido

Ao marcar como perdido:

- exigir `lost_reason`;
- preencher `lost_at`;
- limpar `won_at`;
- preencher `closed_by_id`;
- opcionalmente mover para etapa de categoria `lost`, se existir.

### Conversa Como Origem

A conversa pode criar card automaticamente ou manualmente.

Regra:

- `Conversation` não é lead;
- `Conversation` não é oportunidade;
- `Conversation` é origem/contexto da oportunidade.

### Contato Como Lead

O contato representa a pessoa.

O card deve sempre apontar para `contact_id`.

## Configuracao Do Board

### Tipos De Proxima Acao

Administrador pode configurar uma lista de tipos.

Exemplos:

- Chamar novamente
- Enviar proposta
- Enviar link de pagamento
- Cobrar retorno
- Confirmar pagamento
- Confirmar consulta
- Reagendar
- Enviar contrato
- Outro

MVP deve expor a lista padrão e permitir edição por board em configurações.

### Motivos De Perda

Administrador pode configurar motivos.

Lista padrão:

- Sem resposta
- Preço
- Sem interesse
- Não compareceu
- Fora do perfil
- Fechou com outro
- Outro

MVP deve expor a lista padrão e permitir edição por board em configurações.

Ao marcar uma oportunidade como perdida, o modal deve usar a lista configurada no board. Se o card já tiver um motivo salvo que não está mais na lista, o motivo salvo deve continuar visível para evitar perda de contexto.

### Campos Personalizados

Campos personalizados são definidos por board e preenchidos por card.

Tipos permitidos:

- texto;
- texto longo;
- inteiro;
- decimal;
- moeda;
- data;
- data/hora;
- seleção única;
- seleção múltipla;
- checkbox;
- fórmula;
- URL.

Cada campo deve ter:

- chave estável;
- label;
- tipo;
- opções, quando aplicável;
- visibilidade no card compacto;
- layout/seção;
- posição;
- largura;
- obrigatoriedade opcional por etapa;
- condição opcional de exibição;
- fórmula opcional quando o tipo for fórmula.

Formato sugerido de `custom_field_definitions`:

```json
[
  {
    "key": "consulta_realizada",
    "label": "Consulta realizada?",
    "field_type": "select",
    "options": ["Sim", "Não"],
    "required_stage_ids": [],
    "condition": {},
    "formula": null,
    "layout": {
      "section": "qualification",
      "position": 1,
      "width": "half"
    }
  },
  {
    "key": "valor_total",
    "label": "Valor total",
    "field_type": "formula",
    "options": [],
    "required_stage_ids": [3],
    "condition": {
      "field_key": "consulta_realizada",
      "equals": "Sim"
    },
    "formula": "procedimento + exames",
    "layout": {
      "section": "commercial",
      "position": 2,
      "width": "half"
    }
  }
]
```

Formato sugerido de `custom_field_values`:

```json
{
  "consulta_realizada": "Sim",
  "procedimento": 100.5,
  "exames": 25,
  "valor_total": 125.5
}
```

### Condicionais

Condição MVP:

- `field_key`;
- `equals`.

Regra:

- se a condição estiver vazia, o campo aparece sempre;
- se `custom_field_values[field_key] == equals`, o campo aparece;
- se o campo não aparecer, ele não deve bloquear obrigatoriedade.

### Formulas

Campos `formula` são somente leitura no card e calculados no backend ao salvar.

Regras MVP:

- aceitar operações `+`, `-`, `*`, `/` e parênteses;
- aceitar apenas referências a chaves de campos numéricos;
- valores vazios contam como `0`;
- fórmula inválida deve gerar erro de validação;
- não executar código arbitrário.

### Obrigatoriedade Por Etapa

`required_stage_ids` define em quais etapas o campo é obrigatório.

Regra:

- ao criar/atualizar/mover card para uma etapa listada, validar o preenchimento;
- se o campo tiver condição e a condição não for satisfeita, ele não é obrigatório;
- retornar erro claro para o frontend exibir qual campo falta.

## UI

### Card Compacto

Deve mostrar:

- contato;
- inbox/canal;
- responsável comercial;
- assunto ou contexto;
- valor, quando existir;
- próximo passo;
- badge de status do próximo passo;
- indicador de ganho/perda quando fechado.

### Modal De Card

Deve permitir:

- editar assunto;
- editar descrição/observação comercial em campo compacto;
- editar valor;
- editar responsável comercial por select de agente;
- editar próximo passo usando tipos configurados no board;
- marcar próximo passo como concluído;
- marcar ganho;
- marcar perdido com motivo configurado no board;
- abrir conversa;
- editar campos personalizados quando existirem.

### Filtros

MVP:

- responsável comercial;
- inbox;
- próximo passo hoje;
- atrasados;
- sem próximo passo;
- ganho/perdido, se cards fechados permanecerem visíveis.

### Board Settings

Implementado:

- etapas;
- visibilidade;
- inboxes;
- auto criação por conversas;
- tipos de próxima ação;
- motivos de perda;
- campos personalizados;
- layout de campos;
- regras condicionais;
- fórmulas;
- obrigatoriedade por etapa;
- campos visíveis no card compacto;
- alerta de tempo parado por etapa.

Os templates são escolhidos na criação do board: venda por WhatsApp, clínica/consulta, serviço B2B e funil em branco.

### Navegacao E Contexto

Kanban deve aparecer como item próprio no sidebar usando ícone consistente com o Chatwoot.

Além da tela principal do funil:

- conversa deve expor oportunidades vinculadas ao contato/conversa;
- contato deve ter grupo/aba Kanban com oportunidades;
- criar oportunidade a partir da conversa deve preencher contato, inbox e conversa quando possível;
- abrir card deve permitir voltar para a conversa.

### Relatorios Simples

MVP de relatórios deve expor:

- total aberto;
- total ganho;
- total perdido;
- valor aberto;
- valor ganho;
- valor perdido;
- quantidade por etapa;
- quantidade por responsável;
- atrasados por responsável;
- motivos de perda;
- cards parados por etapa e responsável;
- agenda de ações atrasadas e de hoje.

## API

### Atualizar Card

Endpoint existente de atualização de card deve aceitar novos campos comerciais:

- `owner_id`;
- `next_action_type`;
- `next_action_at`;
- `next_action_note`;
- `next_action_completed_at`;
- `lost_reason`;
- `won_at`;
- `lost_at`;
- `amount_cents`;
- `amount_currency`;
- `custom_field_values`.

### Filtros De Cards

Adicionar filtros:

- `next_action=due_today`;
- `next_action=overdue`;
- `next_action=missing`;
- `status=open`;
- `status=won`;
- `status=lost`.

### Configuracao Do Board

Endpoint de settings deve aceitar no MVP:

- `next_action_types`;
- `lost_reason_options`;
- `custom_field_definitions`;
- `compact_card_field_keys`;
- `stale_stage_thresholds`.

### Relatorios

Endpoint sugerido:

- `GET /api/v1/accounts/:account_id/kanban_boards/:kanban_board_id/reports/sales_summary`

Resposta sugerida:

```json
{
  "open_count": 10,
  "won_count": 4,
  "lost_count": 2,
  "open_amount_cents": 500000,
  "won_amount_cents": 250000,
  "lost_amount_cents": 120000,
  "overdue_count": 3,
  "stale_count": 2,
  "by_stage": [],
  "by_owner": [],
  "lost_reasons": [],
  "agenda": []
}
```

## Banco De Dados

### Campos Persistidos

Adicionar em `kanban_boards`:

- `next_action_types jsonb`;
- `lost_reason_options jsonb`;
- `custom_field_definitions jsonb`;
- `compact_card_field_keys jsonb`;
- `stale_stage_thresholds jsonb`;

Adicionar em `kanban_cards`:

- `owner_id bigint`;
- `next_action_type string`;
- `next_action_at datetime`;
- `next_action_note text`;
- `next_action_completed_at datetime`;
- `won_at datetime`;
- `lost_at datetime`;
- `lost_reason string`;
- `closed_by_id bigint`;
- `amount_cents bigint`;
- `amount_currency string`;
- `custom_field_values jsonb`;
- `next_action_history jsonb`.

Indices sugeridos:

- `account_id, next_action_at`;
- `kanban_board_id, next_action_at`;
- `owner_id, next_action_at`;
- `kanban_board_id, lost_at`;
- `kanban_board_id, won_at`.

## Permissoes

Administrador:

- cria board;
- configura board;
- configura etapas;
- configura tipos, motivos e campos;
- vê boards permitidos pela política atual.

Agente:

- vê boards em que tem permissão;
- move cards;
- edita próximo passo;
- marca ganho/perda se a política permitir editar card;
- abre conversa.

## Automacoes

Nao fazer automações complexas no MVP.

Permitido no MVP:

- destaque visual;
- filtros;
- criação automática configurável por board/inbox;
- criação manual a partir da conversa ou contato;
- opcionalmente nota privada manual ou futura.

Futuro:

- notificação interna quando próximo passo vence;
- nota privada automática;
- automação por mudança de etapa;
- mensagem automática opcional, com configuração explícita.

## Criterios De Aceite MVP

- Vendedor consegue criar ou abrir uma oportunidade no Kanban.
- Vendedor consegue definir próximo passo com tipo, data/hora e observação.
- Vendedor consegue editar o responsável comercial da oportunidade.
- Vendedor escolhe o tipo de próxima ação a partir da lista configurada no board.
- Card sem próximo passo aparece destacado quando aberto.
- Card com próximo passo hoje aparece destacado.
- Card com próximo passo atrasado aparece destacado.
- Filtros de hoje, atrasado e sem próximo passo funcionam.
- Vendedor consegue marcar card como ganho.
- Vendedor consegue marcar card como perdido informando motivo.
- Vendedor escolhe o motivo de perda a partir da lista configurada no board.
- Vendedor consegue preencher valor da oportunidade.
- Administrador consegue configurar tipos de próxima ação por board.
- Administrador consegue configurar motivos de perda por board.
- Administrador consegue configurar campos personalizados por board.
- Campo obrigatório por etapa bloqueia avanço sem preenchimento.
- Campo condicional aparece somente quando a condição é satisfeita.
- Campo fórmula calcula valor a partir de outros campos.
- Card continua abrindo a conversa do Chatwoot.
- Conversa/contato permitem criar ou acessar oportunidade vinculada.
- Relatório simples mostra ganhos, perdidos, atrasados, etapas e responsáveis.
- Nada no fluxo exige consulta ou reunião.
- Venda 100% via WhatsApp é suportada.

## Cobertura Automatizada

### Backend

- validação de estados ganho/perdido;
- filtros de próximo passo;
- permissões de edição;
- consistência entre board, stage, contact, inbox e card;
- motivo de perda obrigatório ao perder;
- next action não obrigatório para cards fechados.
- settings do board retornam tipos de próxima ação e motivos de perda;
- settings do board salvam tipos de próxima ação e motivos de perda;
- normalização remove opções vazias e duplicadas.

### Frontend

- renderização de badges: hoje, atrasado, sem próximo passo;
- edição de próximo passo;
- edição de responsável comercial;
- listas configuradas aparecem no modal de card;
- filtros;
- marcar ganho/perda;
- card sem consulta/reunião;
- abertura de conversa.

### Validacao E2E Recomendada

Fluxo:

1. lead chega no WhatsApp;
2. vendedor cria card;
3. define próximo passo;
4. card aparece em "Hoje";
5. vendedor move para proposta;
6. marca ganho ou perdido.

## Cuidados

- Não usar i18n frontend para tokens literais como `{{agent}}`; manter tokens em constantes JS ou backend config.
- Não adicionar dependências sem necessidade.
- Não misturar suporte pós-venda com pipeline comercial.
- Não criar etapa sem critério claro.
- Não permitir que "consulta" vire regra global.

## Sequencia Implementada

1. Modelar campos de próximo passo e fechamento.
2. Expor campos na API de card.
3. Adicionar badges e filtros no backend.
4. Adicionar UI simples de próximo passo no modal.
5. Adicionar filtros no Kanban.
6. Adicionar ganho/perda com motivo.
7. Rodar testes backend e frontend.
8. Evoluir campos personalizados, templates, alertas, agenda e relatórios.
