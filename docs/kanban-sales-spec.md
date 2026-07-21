# Spec: Kanban Comercial Personalizavel

Baseado em: [PRD: Kanban Comercial no Chatwoot](./kanban-sales-prd.md)

Status: implementação estrutural avançada; validação E2E de acessibilidade/mobile pendente

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

O histórico não substitui logs técnicos e não deve armazenar conteúdo sensível de mensagens desnecessariamente.

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
- recorrência anual baseada em `contact.date_of_birth`;
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

1. lembrete relativo ao campo de data/hora de agendamento selecionado no board;
2. cadência de follow-up inscrita manualmente ou por evento de etapa;
3. aniversário recorrente usando `contact.date_of_birth`, independente de oportunidade.

## Gate De Conclusao Estrutural

O módulo de automações só entra em implementação depois de estes itens P0 estarem aceitos:

- semântica de etapas abertas/ganhas/perdidas;
- linha do tempo completa da oportunidade;
- movimentação assistida com rollback visual;
- busca, ordenação e filtros salvos;
- construtor de condições e fórmulas sem ambiguidade;
- aviso de duplicidade compreensível;
- UX responsiva e acessível validada em desktop e mobile.

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
9. fundação de atributos canônicos do contato;
10. PRD e spec separados do módulo de automações;
11. lembrete de agendamento;
12. cadência de follow-up;
13. aniversário e outras recorrências.
