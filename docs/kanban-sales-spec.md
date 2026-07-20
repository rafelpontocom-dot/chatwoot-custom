# Spec: Kanban Comercial Personalizavel

Baseado em: [PRD: Kanban Comercial no Chatwoot](./kanban-sales-prd.md)

Status: especificação inicial

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

Campos futuros sugeridos:

- `next_action_types`: lista configurável de tipos de próxima ação;
- `lost_reason_options`: lista configurável de motivos de perda;
- `card_field_schema`: definição dos campos personalizados do board;
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

Campos comerciais sugeridos para MVP:

- `owner_id`: responsável comercial, quando diferente do responsável da conversa;
- `next_action_type`;
- `next_action_at`;
- `next_action_note`;
- `next_action_completed_at`;
- `won_at`;
- `lost_at`;
- `lost_reason`;
- `closed_by_id`;

Campos futuros:

- `custom_attributes`: JSONB com campos personalizados do board;
- `estimated_value_cents`;
- `estimated_value_currency`;

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

- card aberto deve ter etapa e responsável;
- card aberto deve poder ter próximo passo;
- se o board exigir próximo passo, card aberto sem `next_action_at` fica destacado.

### Proxima Acao

`next_action_at` define quando o vendedor precisa agir.

`next_action_type` deve vir das opções configuradas no board, quando houver opções.

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

MVP pode iniciar com lista padrão editável posteriormente.

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

### Campos Personalizados

Fase 2.

Tipos permitidos:

- texto;
- número;
- moeda;
- data;
- data/hora;
- seleção única;
- seleção múltipla;
- checkbox;
- URL.

Cada campo deve ter:

- chave estável;
- label;
- tipo;
- opções, quando aplicável;
- visibilidade no card compacto;
- obrigatoriedade opcional por etapa, futuramente.

## UI

### Card Compacto

Deve mostrar:

- contato;
- inbox/canal;
- responsável;
- assunto ou contexto;
- próximo passo;
- badge de status do próximo passo;
- indicador de ganho/perda quando fechado.

### Modal De Card

Deve permitir:

- editar assunto;
- editar descrição/observação comercial;
- editar próximo passo;
- marcar próximo passo como concluído;
- marcar ganho;
- marcar perdido com motivo;
- abrir conversa;
- editar campos personalizados quando existirem.

### Filtros

MVP:

- responsável;
- inbox;
- próximo passo hoje;
- atrasados;
- sem próximo passo;
- ganho/perdido, se cards fechados permanecerem visíveis.

### Board Settings

MVP:

- etapas;
- visibilidade;
- inboxes;
- auto criação por conversas.

Fase 2:

- tipos de próxima ação;
- motivos de perda;
- campos personalizados;
- templates de board.

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
- `lost_at`.

### Filtros De Cards

Adicionar filtros:

- `next_action=due_today`;
- `next_action=overdue`;
- `next_action=missing`;
- `status=open`;
- `status=won`;
- `status=lost`.

### Configuracao Do Board

Endpoint de settings deve futuramente aceitar:

- `next_action_types`;
- `lost_reason_options`;
- `card_field_schema`;
- `compact_card_field_keys`.

## Banco De Dados

### MVP Migration Sugerida

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

Indices sugeridos:

- `account_id, next_action_at`;
- `kanban_board_id, next_action_at`;
- `owner_id, next_action_at`;
- `kanban_board_id, lost_at`;
- `kanban_board_id, won_at`.

### Fase 2 Migration Sugerida

Adicionar em `kanban_boards`:

- `next_action_types jsonb`;
- `lost_reason_options jsonb`;
- `card_field_schema jsonb`;
- `compact_card_field_keys jsonb`;

Adicionar em `kanban_cards`:

- `custom_attributes jsonb`.

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
- opcionalmente nota privada manual ou futura.

Futuro:

- notificação interna quando próximo passo vence;
- nota privada automática;
- automação por mudança de etapa;
- mensagem automática opcional, com configuração explícita.

## Criterios De Aceite MVP

- Vendedor consegue criar ou abrir uma oportunidade no Kanban.
- Vendedor consegue definir próximo passo com tipo, data/hora e observação.
- Card sem próximo passo aparece destacado quando aberto.
- Card com próximo passo hoje aparece destacado.
- Card com próximo passo atrasado aparece destacado.
- Filtros de hoje, atrasado e sem próximo passo funcionam.
- Vendedor consegue marcar card como ganho.
- Vendedor consegue marcar card como perdido informando motivo.
- Card continua abrindo a conversa do Chatwoot.
- Nada no fluxo exige consulta ou reunião.
- Venda 100% via WhatsApp é suportada.

## Testes Recomendados

### Backend

- validação de estados ganho/perdido;
- filtros de próximo passo;
- permissões de edição;
- consistência entre board, stage, contact, inbox e card;
- motivo de perda obrigatório ao perder;
- next action não obrigatório para cards fechados.

### Frontend

- renderização de badges: hoje, atrasado, sem próximo passo;
- edição de próximo passo;
- filtros;
- marcar ganho/perda;
- card sem consulta/reunião;
- abertura de conversa.

### E2E Futuro

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
- Não criar custom fields antes de estabilizar próximo passo.
- Não misturar suporte pós-venda com pipeline comercial.
- Não criar etapa sem critério claro.
- Não permitir que "consulta" vire regra global.

## Sequencia De Implementacao Recomendada

1. Modelar campos de próximo passo e fechamento.
2. Expor campos na API de card.
3. Adicionar badges e filtros no backend.
4. Adicionar UI simples de próximo passo no modal.
5. Adicionar filtros no Kanban.
6. Adicionar ganho/perda com motivo.
7. Rodar testes backend e frontend.
8. Só depois evoluir custom fields.
