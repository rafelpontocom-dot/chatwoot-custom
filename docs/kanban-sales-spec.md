# Spec: Kanban Comercial Personalizavel

Baseado em: [PRD: Kanban Comercial no Chatwoot](./kanban-sales-prd.md)

Status: implementação avançada; E2E real preparada em Playwright e validação de produção pendente

Execucao: [Roadmap do Workspace Comercial](./kanban-commercial-workspace-roadmap.md)

## Objetivo Da Spec

Transformar o PRD em comportamento implementável, preservando o Kanban atual e evoluindo-o para venda.

Esta spec evita decisões que acoplem o produto a consulta, reunião ou qualquer ciclo comercial específico.

Esta spec também define a fronteira entre o Kanban e o futuro módulo de automações. Recursos pendentes estão marcados como `P0`, `P1` ou `Futuro` e não devem ser descritos como já entregues.

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
- `appointment_reminder_hours`: antecedência do lembrete interno de agendamento; vazio desativa;

Campos comerciais implementados:

- `custom_field_definitions`: definição dos campos personalizados do board;
- `custom_field_sections`: abas personalizadas persistentes do board;
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

- `category`: `open`, `won`, `lost` (`P0`);
- `requires_next_action`: boolean;
- `stale_after_hours`: inteiro opcional.

Regras P0:

- toda etapa deve ter uma categoria;
- boards existentes recebem `open` por padrão, preservando etapas usadas atualmente;
- mover para `won` ou `lost` deve chamar o mesmo serviço de fechamento usado pelo modal;
- etapa `lost` exige motivo de perda antes de concluir a movimentação;
- etapa terminal não pode fechar silenciosamente uma oportunidade se a validação falhar.

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

### Contact

Dados pessoais compartilhados por todas as oportunidades permanecem no contato.

Campo canônico P0 para a fase de automações:

- `date_of_birth`: data sem horário, exposta na ficha do contato.

Implementação inicial recomendada:

- criar ou garantir uma definição de atributo personalizado de contato com chave estável `date_of_birth` e tipo `date` por conta;
- armazenar o valor em `contact.custom_attributes` para manter compatibilidade com APIs, filtros e painel lateral do Chatwoot;
- não copiar o valor para `kanban_cards.custom_field_values`;
- validar somente data, sem exigir ano quando uma futura evolução suportar aniversário sem ano;
- consentimento de WhatsApp, idioma e fuso horário também são atributos do contato, não do card.

Implementação atual:

- `20260728100000_provision_contact_date_of_birth_attribute.rb` provisiona a definição por conta;
- `Accounts::ProvisionStandardContactAttributesService` mantém a operação idempotente para novas contas e reprocessamento;
- uma definição existente com a mesma chave é preservada, evitando sobrescrever configuração do cliente;
- o atributo continua sendo preenchido na ficha do contato, não no card.

### KanbanBirthdayAutomation

Configuração anual pertencente à conta, independente de oportunidade:

- `active` habilita o processamento;
- `days_before` permite enviar no dia ou até 30 dias antes;
- `delivery_channels` aceita `whatsapp` e `email`;
- `opt_in_attribute_key` aponta para um atributo booleano de consentimento do contato;
- `timezone` e `send_time` controlam a janela local de envio;
- `message_template` suporta `{{contact_name}}` e `{{birthday_date}}`;
- `whatsapp_template_params` permite usar template aprovado fora da janela de 24 horas.

`KanbanBirthdayDelivery` registra uma entrega por conta, contato, ano e canal. O índice único, lock de processamento e estados `pending`, `sending`, `sent`, `skipped` e `failed` tornam retries idempotentes. Sem opt-in, sem conversa compatível ou fora da janela do WhatsApp sem template aprovado, nada é enviado.

### KanbanAppointmentReminderRule

Regra de lembrete externo vinculada a um board, a um evento de negócio e a um campo `datetime`.

Contrato proposto:

- `kanban_board_id`;
- `trigger_type`: `stage_entered`, `card_created`, `appointment_changed` ou `manual`;
- `trigger_stage_id`, obrigatório quando `trigger_type` for `stage_entered`;
- `field_key`;
- `offsets`, em horas positivas, por exemplo `[48, 24, 2]`;
- `channels`: `whatsapp` e/ou `email`;
- `message_template` e `whatsapp_template_params`;
- `timezone_mode`: `contact`, `board` ou `account`;
- `conditions` opcionais;
- `active` e `lock_version`.

A entrada em uma etapa é apenas o gatilho de elegibilidade. O serviço deve exigir que `field_key` resolva para um `datetime` futuro, que o card esteja aberto e que o contato possa receber a comunicação. A política de reentrada recomendada é `once_per_appointment`: sair e voltar para a etapa não duplica envios. Um reagendamento gera `appointment_version` nova, cancela a versão anterior e recria a programação.

A chave idempotente recomendada é `account_id + rule_id + card_id + appointment_version + offset_hours + channel`. Ao alterar a data, a versão anterior é cancelada e uma nova programação é criada.

Estados de entrega: `scheduled`, `sending`, `sent`, `skipped`, `failed` e `canceled`. O job deve fazer claim com lock, registrar o motivo de não envio e aplicar retry limitado.

Implementação inicial: `KanbanAppointmentReminders::ScheduleService` cria uma entrega por offset e canal quando a oportunidade entra na etapa configurada. `KanbanAppointmentReminders::ProcessDueJob` faz o claim com lock e usa `Messages::MessageBuilder`; o serviço registra `no_compatible_conversation`, `opt_in_required` e `outside_whatsapp_window` como motivos de `skipped`. O scheduler de itens agendados executa esse job separadamente do processamento de cadências internas.

### KanbanCadence

A implementação atual já possui `KanbanCadence` e `KanbanCadenceEnrollment` para lembretes internos. O contrato deve ser preservado, separando ações internas de mensagens externas.

Implementação inicial: `trigger_type = stage_entered` e `trigger_stage_id` permitem inscrever a oportunidade automaticamente na primeira cadência ativa daquela etapa. A inscrição é idempotente em retries do evento; uma oportunidade já ativa ou aguardando conclusão não recebe uma segunda inscrição.

Formato de passo interno:

```json
{
  "delay_hours": 24,
  "action_type": "internal_task",
  "next_action_type": "Cobrar retorno",
  "note": "Verificar se o lead respondeu",
  "conditions": { "incoming_since_previous_step": false }
}
```

Para a fase futura de mensagens externas:

```json
{
  "delay_hours": 48,
  "action_type": "send_message",
  "channel": "whatsapp",
  "template_name": "followup_48h",
  "requires_opt_in": true,
  "stop_if_customer_replied": true
}
```

`send_message` não deve ser habilitado apenas adicionando um valor no JSON. O backend precisa validar canal, template, consentimento, janela, limite de frequência e permissão do board.

### KanbanCadenceStepExecution

Registro idempotente de cada passo executado:

- `enrollment_id`, `step_index`, `scheduled_at` e `executed_at`;
- `status`: `scheduled`, `sent`, `completed`, `skipped`, `failed` ou `canceled`;
- `message_id`, quando houver;
- `idempotency_key` única;
- `error_message` e `metadata`.

Esse registro evita duplicidade em retries do Sidekiq e permite mostrar no card exatamente o que ocorreu.

### Fluxo De Cadencia

1. `EnrollService` valida board, card, cadência ativa e ausência de execução duplicada.
2. O enrollment agenda o primeiro passo no fuso do board ou da conta.
3. `ProcessDueJob` faz claim com lock e cria a execução do passo.
4. A execução avalia condições e paradas antes de qualquer ação.
5. A ação interna atualiza `next_action_*`; a externa passa pelo serviço do canal.
6. O passo concluído agenda o próximo; uma falha registra erro e segue retry limitado.
7. Mensagem recebida, mudança terminal ou cancelamento manual pausa/cancela o enrollment.

### Politica De Gatilhos

Gatilhos são eventos de domínio, não chamadas diretas de controller. A transição do card deve publicar `kanban.card.stage_entered`, a alteração do campo de consulta deve publicar `kanban.card.appointment_changed` e a criação deve publicar `kanban.card.created`. Um listener encontra regras ativas do board e agenda o serviço correspondente.

O serviço deve ser idempotente e reavaliar as condições no momento do envio. Portanto, mover para `Agendado` não garante envio: a oportunidade ainda pode estar sem data, sem conversa compatível, sem opt-in ou fora da política de canal. Cada motivo de não envio deve ser persistido para diagnóstico.

Para cadências de follow-up, a inscrição pode ocorrer ao entrar em uma etapa ou manualmente. A execução deve interromper quando houver resposta do cliente, mudança de etapa configurada como terminal, ganho, perda, arquivamento, opt-out ou cancelamento. O encerramento automático como `Perdido` nunca deve ser implícito: precisa ser uma ação configurada e visível na revisão da cadência.

### Mapeamento Do N8N

Para migrar um workflow existente, cada nó deve ser mapeado para uma categoria: gatilho para origem de enrollment, `Wait` para atraso, condição para `conditions`, envio WhatsApp para ação externa, atualização de campo para `set_field`, troca de etapa para `move_stage`, atribuição para `assign_owner` e resposta do cliente para evento de pausa.

O produto deve oferecer prévia do mapeamento, listar nós não suportados e nunca ativar automaticamente uma cadência migrada sem revisão do administrador.

O workflow de referência `Follow-up Citocenter` foi analisado por API. A equivalência nativa é:

- Webhook: evento de inscrição ou mudança de etapa;
- Switch por `acompanhamento_follow_up`: condição de entrada da cadência;
- nós de configuração: versões de uma cadência, não código duplicado por ramo;
- cálculo de agenda: política de atraso e horário comercial configurável;
- nós `Checar antes`: condições avaliadas novamente antes de cada passo;
- labels `fup_*`: eventos/etiquetas de execução, sem depender de texto técnico no atendimento;
- envio: ação de canal validada pelo serviço de mensagens;
- resolver/perder: ação terminal opcional, sempre explícita e revisável.

O N8N atual contém um token de acesso ao Chatwoot gravado dentro do workflow. Antes de manter esse fluxo em produção, o token deve ser revogado/rotacionado e substituído por uma credencial segura do N8N. A integração temporária deve usar apenas uma conta técnica com escopo mínimo e registrar request ID, status e erro sem salvar segredo em logs.

### KanbanCardEvent

Entidade P0 para histórico comercial imutável da oportunidade.

Campos mínimos:

- `account_id`;
- `kanban_board_id`;
- `kanban_card_id`;
- `event_type`;
- `actor_type` e `actor_id`;
- `occurred_at`;
- `changes` em JSON com valores anteriores e novos;
- `metadata` em JSON para origem da alteração, request ID e execução de automação.

Eventos mínimos:

- `card_created`;
- `stage_changed`;
- `owner_changed`;
- `amount_changed`;
- `custom_fields_changed`;
- `next_action_scheduled`;
- `next_action_completed`;
- `card_won`;
- `card_lost`;
- `card_reopened`;
- `card_archived` e `card_restored` quando a fase P1 existir.

Eventos de dominio publicados apos o commit, para o modulo futuro de automacoes e integracoes:

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

Esses eventos carregam o identificador do evento imutavel e o snapshot minimo da oportunidade. `kanban.card.created` permanece publicado pelos servicos de criacao existentes para manter compatibilidade com os consumidores atuais.

O histórico não substitui logs técnicos e não deve armazenar conteúdo sensível de mensagens desnecessariamente.

### KanbanAutomationRule

Regra comercial pertencente a um board. O contrato inicial aceita:

- `event_name` entre os eventos `kanban.card.*` publicados pelo Kanban;
- condições opcionais por `inbox_ids`, `stage_ids`, `owner_ids` e `fields`;
- operadores de campo `equals`, `not_equals`, `contains`, `exists`, `greater_than`, `greater_or_equal`, `less_than` e `less_or_equal`;
- ações internas `move_stage`, `assign_owner`, `set_next_action`, `set_field` e `archive_card`.

O backend valida que todas as referências pertencem à conta e ao board da regra. Nenhuma ação dessa primeira fase envia mensagem ao cliente.

### KanbanAutomationExecution

Cada regra/evento possui uma execução idempotente por `event_key`. A execução registra status, início, conclusão, resultado por ação e erro. Reprocessamentos podem ocorrer para execuções falhas, mas execuções concluídas com sucesso não são repetidas.

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

`layout.section` identifica a aba do modal. Os valores reservados são:

- `details`: aba Geral;
- `marketing`: aba Marketing.

Abas adicionais são persistidas em `custom_field_sections`, no formato `{ key, label }`. As chaves `details`, `marketing` e `timeline` são reservadas. Campos sem `layout.section` permanecem em `details` para manter compatibilidade com boards existentes.

O card apresenta `Geral`, `Marketing`, as abas personalizadas e `Linha do tempo`. Para administradores, uma engrenagem abre o gerenciador do board e o botão `+` inicia a criação de uma aba sem exigir saída manual do contexto da oportunidade.

As configurações do board devem oferecer um editor visual com `vuedraggable`. Mover um campo entre áreas atualiza `layout.section`; reordenar um campo atualiza `layout.position`. `layout.width` continua controlando a largura do campo dentro da aba.

O botão de preset de Marketing substitui somente campos conhecidos do preset na seção Marketing, remove chaves obsoletas e preserva campos desconhecidos criados pelo cliente. A ordem e as chaves canônicas são: `origem_do_lead`, `sub_origem`, `campaign`, `adset`, `ad`, `utm_content`, `utm_medium`, `utm_campaign`, `utm_source`, `utm_term`, `utm_referrer`, `referrer`, `gclientid`, `gclid`, `fvclid`, `ttad_name`, `ttad_id`, `fbc`, `fbp`, `ttclid`, `campaign_id`, `adset_id`, `ad_id`, `landing_page`, `event_id` e `landing_page_full`.

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
- aceitar referências ao valor da oportunidade, a campos inteiros, decimais, monetários e a fórmulas anteriores;
- valores vazios contam como `0`;
- aceitar ponto ou vírgula como separador decimal em constantes;
- fórmula inválida deve gerar erro de validação;
- não executar código arbitrário.

Semântica da configuração:

- `condition.field_key` + `condition.equals` controlam visibilidade;
- `formula` contém exclusivamente a expressão matemática;
- a expressão não inclui atribuição: usar `procedimento + exames`, nunca `valor_total = procedimento + exames`;
- a UI nunca salva expressão matemática em `condition.equals`;
- o editor de fórmula só aparece para `field_type = formula`;
- digitar `[` abre todos os campos numéricos e monetários disponíveis, incluindo `system_amount`;
- digitar depois de `[` filtra por nome; selecionar insere um marcador humanizado como `[Valor da oportunidade]`;
- antes de salvar, a UI converte o marcador humanizado para a chave estável correspondente;
- fórmulas calculadas aparecem como candidatas somente quando estão antes do campo atual; referências futuras e ciclos são inválidos;
- backend continua sendo a autoridade de validação e cálculo.

Campos `date` e `datetime` não são operandos no MVP. Suporte futuro exige `formula_result_type` e regras explícitas para duração, diferença entre datas, soma de dias e preservação de fuso horário.

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

P0 de experiência:

- linha do tempo comercial em aba própria ou seção lateral, paginada;
- ao tentar fechar ou mudar de etapa, listar somente os campos obrigatórios que faltam;
- ao falhar um salvamento, manter os valores editados e informar a correção;
- indicar alterações não salvas antes de fechar o modal;
- suportar foco, teclado e leitura por tecnologia assistiva nas abas e ações principais.

### Filtros

MVP:

- responsável comercial;
- inbox;
- próximo passo hoje;
- atrasados;
- sem próximo passo;
- ganho/perdido, se cards fechados permanecerem visíveis.

P0:

- busca por assunto da oportunidade, nome do contato, telefone e email;
- chips ou resumo dos filtros ativos;
- ação única para limpar filtros;
- ordenação por próxima ação, criação, valor e tempo na etapa;
- filtros salvos por usuário, sem alterar a configuração global do board.

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

P0 de experiência do construtor de campos:

- agrupar cada campo em `Dados básicos`, `Exibição condicional`, `Cálculo` e `Validação por etapa`;
- manter `Exibição condicional` desligada por padrão;
- ao ativar a condição, mostrar selects para campo de origem, operador e valor;
- para campos de seleção e checkbox, oferecer valores válidos em select;
- mostrar `Cálculo` somente para campo do tipo fórmula;
- rotular claramente a expressão como `Fórmula`, nunca como `For igual a`;
- manter JSON apenas em área avançada recolhida;
- apresentar prévia de como o campo aparecerá no card.

### Movimentacao Assistida

Ao arrastar um card:

1. o frontend mantém uma cópia da etapa e posição de origem;
2. se a etapa de destino exigir dados ausentes, abre um modal curto com esses campos;
3. ao confirmar, envia preenchimento e movimentação na mesma operação transacional;
4. ao cancelar ou receber erro, restaura o card na origem;
5. ao concluir, informa sucesso sem recarregar todo o board quando não for necessário.

Movimentação para etapa `won` ou `lost` segue as regras de fechamento e histórico.

### Migracao Do Kommo

Fora do escopo do produto. Caso seja necessária, será executada como operação de dados separada, sem adicionar uma interface permanente de importação ao Kanban.

### Navegacao E Contexto

Kanban deve aparecer como item próprio no sidebar usando ícone consistente com o Chatwoot.

Além da tela principal do funil:

- conversa deve expor oportunidades vinculadas ao contato/conversa;
- contato deve ter grupo/aba Kanban com oportunidades;
- criar oportunidade a partir da conversa deve preencher contato, inbox e conversa quando possível;
- abrir card deve permitir voltar para a conversa.

### Indicadores Compactos

A tela do board deve exibir somente:

- total aberto;
- total ganho;
- total perdido;
- total atrasado;
- valor ganho.

O frontend não deve renderizar painel detalhado por etapa/responsável, motivos de perda ou agenda. Os dados adicionais já existentes no payload podem permanecer disponíveis para compatibilidade, sem exposição nessa tela.

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
- `custom_field_sections`;
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
- `custom_field_sections jsonb`;
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

Quando Custom Roles está disponível, as operações comerciais são separadas em:

- `kanban_view`: listar e abrir boards e oportunidades;
- `kanban_create`: criar oportunidades;
- `kanban_edit`: editar dados da oportunidade;
- `kanban_assign`: alterar o responsável comercial;
- `kanban_move`: mover e reordenar oportunidades;
- `kanban_close`: marcar ganho, perda ou reabertura;
- `kanban_bulk`: executar ações comerciais em massa;
- `kanban_configure`: configurar board, etapas, campos e automações;
- `kanban_manage`: arquivar, restaurar e excluir board ou oportunidade;
- `kanban_report`: consultar resumo, atividades e exportações comerciais.

Administradores mantêm acesso completo. Contas sem Custom Role preservam o comportamento legado de agentes. A visibilidade do board continua sendo aplicada antes da autorização da operação.

Para não quebrar Custom Roles criados antes da separação fina, `kanban_edit` também continua concedendo criação; novos perfis podem usar `kanban_create` isoladamente.

## Automacoes

Não colocar o construtor de automações dentro do Kanban.

Permitido no MVP:

- destaque visual;
- filtros;
- criação automática configurável por board/inbox;
- criação manual a partir da conversa ou contato;
- opcionalmente nota privada manual ou futura.

Futuro:

- módulo próprio baseado em `gatilho -> condições -> ações`;
- gatilhos de evento do card, contato e conversa;
- gatilhos relativos a campos de data/hora;
- notificações internas, tarefas e notas privadas;
- mensagens automáticas opcionais e controladas;
- cadências com mensagem, espera, tarefa manual, pausa e saída.

Contrato mínimo que o Kanban deve oferecer ao módulo futuro:

- eventos de domínio versionados e idempotentes;
- snapshot mínimo com IDs de conta, board, card, etapa, contato, conversa e responsável;
- suporte a `correlation_id` para rastrear uma execução;
- ações de atualizar card, mover etapa, definir próxima ação, inscrever e retirar de cadência;
- nenhuma mensagem enviada diretamente por callback de modelo ou controller do Kanban.

Guardrails obrigatórios para mensagens:

- opt-in e opt-out por contato e categoria;
- template aprovado fora da janela de atendimento do WhatsApp;
- fuso horário e janela de envio;
- limite de frequência;
- idempotência para não repetir mensagem em retry;
- pausa ao receber resposta quando configurado;
- cancelamento por ganho, perda, agendamento cancelado ou intervenção manual;
- histórico de execução visível e reprocessamento administrativo controlado.

Casos de uso iniciais da próxima fase:

1. notificação externa relativa ao campo de data/hora de agendamento selecionado no board;
2. cadência de follow-up inscrita manualmente ou por evento de etapa.

Aniversário já possui uma primeira automação controlada por conta: usa `contact.date_of_birth`, opt-in, timezone, horário, WhatsApp/email e registro idempotente por ano e canal.

Implementacao atual de cadencias internas:

- `KanbanCadence` pertence a conta e board e armazena no maximo 20 passos;
- cada passo aceita `delay_hours`, `action_type` e `note`;
- `KanbanCadenceEnrollment` vincula uma oportunidade a uma cadencia e controla os estados `active`, `awaiting_completion`, `paused`, `completed` e `canceled`;
- o job `KanbanCadences::ProcessDueJob` roda no scheduler de cinco minutos;
- um passo vencido define a proxima acao do card e aguarda a conclusao do agente;
- concluir a proxima acao agenda o passo seguinte;
- mensagem recebida do cliente, ganho, perda e arquivamento pausam a inscricao;
- lembrete de agendamento configurado no board cria uma proxima acao interna antes de `starts_at`;
- o scheduler nao altera uma proxima acao manual existente e protege a criacao com lock;
- a configuracao deixa explicito que a cadencia e interna e nao envia mensagens ao cliente.

Lembrete interno de agendamento:

- `appointment_reminder_hours` aceita vazio ou inteiro entre `0` e `168`;
- o scheduler cria `Lembrete de agendamento` como próxima ação quando `starts_at` é futuro e o card não possui próxima ação;
- a próxima ação manual nunca é sobrescrita;
- a criação usa lock por card para ser idempotente em execuções concorrentes;
- a central de atividades exibe os agendamentos separadamente e não envia mensagens.

Ainda fora do escopo: notificações internas no feed do Chatwoot, calendário externo, WhatsApp/email para eventos diferentes do aniversário e editor completo de automações multicanal.

## Gate De Conclusao Estrutural

O módulo de automações só entra em implementação depois de estes itens P0 estarem aceitos:

- semântica de etapas abertas/ganhas/perdidas;
- linha do tempo completa da oportunidade;
- movimentação assistida com rollback visual;
- busca, ordenação e filtros salvos;
- construtor de condições e fórmulas sem ambiguidade;
- aviso de duplicidade compreensível;
- UX responsiva e acessível validada em desktop e mobile.

A suíte real está em `tests/playwright/tests/e2e/ui/kanban-accessibility.spec.ts`. Ela cobre desktop Chrome e Pixel 7, foco por teclado, filtro, drawer, Escape, nomes acessíveis, tablist e overflow do cabeçalho. A execução depende de ambiente e dados semeados:

```bash
cd tests/playwright
KANBAN_E2E=1 BASE_URL=https://seu-ambiente \
  TEST_USER_EMAIL=... TEST_USER_PASSWORD=... pnpm run playwright:run
```

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
- Resumo compacto mostra abertas, ganhas, perdidas, atrasadas e valor ganho.
- Card organiza campos por abas e abre inicialmente na aba Geral.
- Administrador consegue arrastar campos entre abas e reordená-los.
- Preset de Marketing sincroniza o conjunto canônico sem duplicar chaves e preserva campos desconhecidos criados pelo cliente.
- Nada no fluxo exige consulta ou reunião.
- Venda 100% via WhatsApp é suportada.

## Criterios De Aceite Do Fechamento P0

## Visao Lista E Central De Atividades

### Lista

`KanbanListView` é uma projeção da resposta atual do board. Ela deve:

- renderizar oportunidade, contato, etapa, valor, próxima ação, responsável e última atividade;
- reutilizar `selectedCardIds` e as ações em massa do board;
- abrir o mesmo detalhe e a mesma conversa da visão Kanban;
- funcionar em viewport estreito com rolagem horizontal controlada, sem sobrepor texto;
- informar quando somente os cards carregados estão visíveis e permitir ampliar a carga pelo fluxo existente.

Não deve existir endpoint ou persistência paralela para a lista.

### Central De Atividades

`KanbanActivityCenter` é uma visão de trabalho separada dos relatórios. Ela agrupa cards carregados por:

- hoje;
- atrasadas;
- próximas;
- sem próxima ação;
- agendamentos de hoje e futuros, usando `starts_at`;
- responsável.

Cada item emite a abertura do detalhe. A consulta remota é paginada no backend e a aba de agendamentos ordena pela data/hora de início. A central não envia lembretes nem mensagens ao cliente; ela apenas organiza o trabalho do agente.

### Prévia De Drawer

`KanbanOpportunityDrawerPreview` é uma prévia não destrutiva. Ela não salva dados e não substitui o modal atual. O aceite visual deve verificar:

- foco inicial e fechamento por Escape;
- backdrop sem bloquear o conteúdo do drawer;
- largura adequada em desktop e mobile;
- cabeçalho e rodapé fixos durante rolagem;
- navegação por abas sem perda de contexto;
- leitura correta por leitor de tela.

Somente após esse aceite a implementação deve migrar a edição real para drawer.

## Entradas E Autorizacao

- `Nova oportunidade` usa a primeira etapa aberta e o seletor de criação existente.
- Conversa e contato podem criar ou abrir várias oportunidades sem sobrescrever outra.
- Criação automática é controlada por board/inbox.
- Toda operação comercial relevante deve ser validada por policy/service no backend.
- O frontend apenas apresenta capacidades já autorizadas.

## Governanca De Configuracao

- Campos e abas são identificados por chaves estáveis.
- Renomear não altera a chave.
- Remover campo com valores exige contagem de impacto e confirmação.
- Alterações não salvas exigem confirmação ao fechar.
- Alterações de layout são versionadas junto com a configuração do board.
- Histórico de oportunidade não pode ser apagado por edição de campos.

- Usuário encontra uma oportunidade por nome, telefone, email ou assunto sem conhecer a etapa.
- Usuário salva e reutiliza um conjunto de filtros pessoais.
- Arrastar para etapa com campos obrigatórios solicita os dados faltantes e não perde a posição ao cancelar.
- Arrastar para etapa ganha/perdida registra o mesmo estado e histórico do fechamento feito pelo modal.
- Linha do tempo identifica o que mudou, quando e por quem.
- Campo do tipo fórmula mostra editor próprio, campos numéricos disponíveis, validação e prévia.
- `For igual a` aparece apenas dentro da configuração de condição.
- Possível duplicidade informa o motivo e permite entender a oportunidade existente.
- Fluxos essenciais funcionam por teclado e em viewport móvel sem sobreposição.
- Nenhuma ação do Kanban envia mensagem automática antes da ativação explícita do futuro módulo.

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

Também executar os projetos `chromium` e `mobile-chromium`. Para leitor de tela, validar a árvore ARIA do drawer e das abas com VoiceOver no macOS ou NVDA no Windows; a suíte automatizada garante os nomes e estados semânticos que alimentam essa árvore, mas não substitui a tecnologia assistiva real.

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
8. Evoluir campos personalizados, templates, alertas e indicadores compactos.

## Sequencia Recomendada A Partir De Agora

1. semântica das etapas e movimentação assistida;
2. histórico comercial completo;
3. busca, ordenação e filtros salvos;
4. UX final do construtor de campos, condições e fórmulas;
5. acessibilidade, mobile e teste E2E do fluxo integral;
6. confirmação e resumo de impacto para todas as ações em massa;
7. arquivamento e restauração de boards;
8. gerenciamento completo de abas e filtros salvos, além da prévia numérica de fórmulas;
9. aceite E2E real em desktop, mobile, teclado e leitor de tela;
10. testes de produção com concorrência, retries e alto volume;
11. fundação de atributos canônicos do contato;
12. PRD e spec separados do módulo de automações;
13. lembrete de agendamento;
14. cadência de follow-up;
15. aniversário e outras recorrências.
