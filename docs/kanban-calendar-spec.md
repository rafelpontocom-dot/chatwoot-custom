# Spec: Agenda Operacional do RAEVO CRM

Baseado em: [PRD da Agenda](./kanban-calendar-prd.md)

Status: P0 em implementacao. O catalogo inicial de procedimentos/recursos, a rota `/calendar`, os endpoints iniciais, a reserva com exclusao PostgreSQL de conflito, series simples, reagendamento e cancelamento por escopo, e os estados confirmar, concluir, falta e cancelar estao implementados localmente. A configuracao do modulo por funil, janelas semanais, excecoes datadas e consulta de slots por recurso tambem estao disponiveis. O detalhe de reagendamento mostra os slots livres do recurso e a grade preserva agendamentos fora da faixa comercial inicial. A etapa de agendamento abre o drawer da oportunidade para sugerir a reserva; o detalhe da consulta oferece retorno ao card vinculado. Integracoes seguem pendentes.

## Fronteira

O modulo e nativo ao Chatwoot e pertencente a `Account`. Ele se integra ao Kanban por `kanban_card_id`, mas nao exige oportunidade: uma agenda pode receber um contato diretamente. Toda consulta ligada a oportunidade usa o mesmo `KanbanCard`, nunca uma copia de campos em `custom_field_values`.

`KanbanBoard` possui a configuracao de modulo: `calendar_enabled`, `calendar_booking_stage_ids`, `calendar_procedure_ids` e `calendar_legacy_next_appointment_field_key`. Nenhum desses campos armazena sessoes ou recorrencia; eles apenas governam sugestoes e compatibilidade.

O payload do board inclui os tres primeiros campos para que o drawer da oportunidade exiba a area Agenda somente quando habilitada, filtre procedimentos permitidos e sinalize etapas que pedem agendamento. O frontend nunca cria uma ocorrencia apenas pela mudanca de etapa.

### Direcao De Integracao Aprovada

- P0: agenda nativa e fonte de verdade.
- P1: exportacao unidirecional para Google Calendar por recurso/profissional.
- Futuro: Cal.com apenas para autoagendamento; FEEGOW e N8N recebem eventos por conexoes aprovadas.
- Nenhum provedor externo pode criar uma segunda fonte de verdade para horarios, series ou status sem uma politica explicita de sincronizacao.

### Eventos De Agenda

As ocorrencias vinculadas a uma oportunidade publicam `kanban.appointment.created`, `rescheduled`, `canceled`, `confirmed`, `completed` e `no_show`. Cada entrega inclui `account_id`, `board_id`, `card_id`, `appointment_id`, versao, status e intervalo. A chave de idempotencia e `appointment:<id>:<evento>:v<versao>` e nao reutiliza a chave de eventos historicos do card.

O contexto de execucao preserva `appointment_starts_at`. O no visual `wait_until_field` aceita `system_appointment_starts_at`, permitindo offsets negativos para lembretes antes da consulta.

## Modelo De Dados P0

### CalendarResource

Representa uma capacidade reservavel.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatorio, indexado |
| `name` | string | obrigatorio |
| `resource_type` | enum | `user`, `room`, `equipment`, `generic` |
| `user_id` | bigint | opcional; obrigatorio para `user` |
| `timezone` | string | IANA, obrigatorio |
| `active` | boolean | padrao `true` |
| `capacity` | integer | P0 exige `1` |
| `settings` | jsonb | dados de exibicao e futuras extensoes |

Indice unico recomendado: `account_id, user_id` quando `user_id` estiver presente.

### CalendarAvailabilityRule

Disponibilidade recorrente semanal ou excecao pontual de recurso.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `calendar_resource_id` | bigint | obrigatorio |
| `kind` | enum | `weekly_window`, `date_override`, `block` |
| `weekday` | integer | obrigatorio para `weekly_window`, 0..6 |
| `starts_at_local` | time | horario local |
| `ends_at_local` | time | fim exclusivo, maior que inicio |
| `date` | date | obrigatorio para override/bloqueio |
| `active` | boolean | padrao `true` |

P0 calcula slots em tempo de leitura; nao pregera meses de slots no banco.

### CalendarProcedure

Define o tipo de atendimento configuravel.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatorio |
| `name` | string | obrigatorio, unico por conta sem diferenca de caixa |
| `color` | string | token/hex permitido |
| `duration_minutes` | integer | 5..480 |
| `buffer_before_minutes` | integer | 0..120 |
| `buffer_after_minutes` | integer | 0..120 |
| `location_type` | enum | `in_person`, `video`, `phone`, `other` |
| `recurrence_enabled` | boolean | padrao `false` |
| `max_recurrence_count` | integer | 1..100 |
| `allowed_intervals` | jsonb | `weekly`, `biweekly`, `monthly`, `days:N` |
| `board_ids` | jsonb | boards elegiveis; vazio significa todos |
| `stage_policy` | jsonb | sugestoes por evento, nunca mudanca oculta |
| `active` | boolean | padrao `true` |

Recursos elegiveis usam tabela de juncao `CalendarProcedureResource` com `calendar_procedure_id` e `calendar_resource_id`.

### CalendarAppointmentSeries

Agrupa um plano recorrente. Uma serie pode possuir uma unica ocorrencia; isso simplifica a evolucao sem mudar referencias.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatorio |
| `contact_id` | bigint | obrigatorio |
| `kanban_card_id` | bigint | opcional |
| `calendar_procedure_id` | bigint | obrigatorio |
| `status` | enum | `active`, `completed`, `canceled` |
| `planned_count` | integer | 1..100 |
| `interval_kind` | enum | `once`, `weekly`, `biweekly`, `monthly`, `days` |
| `interval_days` | integer | obrigatorio apenas para `days` |
| `timezone` | string | IANA, obrigatorio |
| `started_at` | datetime | primeira ocorrencia |
| `ended_at` | datetime | opcional |
| `metadata` | jsonb | somente dados comerciais permitidos |
| `lock_version` | integer | optimistic locking |

### CalendarAppointment

Uma ocorrencia real de atendimento.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatorio |
| `calendar_appointment_series_id` | bigint | obrigatorio |
| `contact_id` | bigint | obrigatorio |
| `kanban_card_id` | bigint | opcional |
| `calendar_procedure_id` | bigint | obrigatorio |
| `status` | enum | abaixo |
| `starts_at` / `ends_at` | datetime | UTC, inicio menor que fim |
| `timezone` | string | IANA de exibicao e calculo |
| `occurrence_number` | integer | unico na serie |
| `appointment_version` | integer | inicia em 1; cresce no reagendamento |
| `rescheduled_from_id` | bigint | opcional |
| `canceled_at` | datetime | somente cancelada |
| `canceled_by_id` | bigint | somente cancelada |
| `cancellation_reason` | string | somente cancelada |
| `completed_at` | datetime | somente concluida |
| `no_show_at` | datetime | somente falta |
| `notes` | text | acesso restrito; nunca enviado externamente |
| `external_refs` | jsonb | ids futuros de provedores |
| `lock_version` | integer | optimistic locking |

Estados: `scheduled`, `confirmed`, `checked_in`, `completed`, `no_show`, `canceled`.

### CalendarAppointmentResource

Juncao entre ocorrencia e todo recurso que ela bloqueia. Uma consulta pode exigir profissional e sala.

| Campo | Tipo |
| --- | --- |
| `calendar_appointment_id` | bigint |
| `calendar_resource_id` | bigint |
| `starts_at` / `ends_at` | datetime |

Indice essencial: `calendar_resource_id, starts_at, ends_at`.

O P0 tambem usa exclusao PostgreSQL para impedir sobreposicao de intervalos ativos por recurso:

```sql
EXCLUDE USING gist (
  calendar_resource_id WITH =,
  tstzrange(starts_at, ends_at, '[)') WITH &&
)
WHERE (appointment_status IN ('scheduled', 'confirmed', 'checked_in'));
```

A migration deve habilitar `btree_gist` e materializar `appointment_status` na juncao ou usar outra modelagem equivalente que preserve a garantia no banco. Validacao Ruby so melhora a mensagem; ela nao substitui a restricao transacional.

### CalendarAppointmentEvent

Auditoria append-only.

- `created`, `confirmed`, `rescheduled`, `canceled`, `completed`, `no_show`, `series_split`, `reminder_canceled`, `external_sync`;
- `actor_id`, `occurred_at`, `metadata` permitida;
- nunca registrar token, payload completo externo ou conteudo clinico sensivel.

## Servicos

| Servico | Responsabilidade |
| --- | --- |
| `Calendar::AvailabilityQuery` | calcula janelas livres por recurso, procedimento, data e fuso |
| `Calendar::BookAppointmentService` | valida recursos, cria serie/ocorrencias e eventos em transacao |
| `Calendar::RescheduleAppointmentService` | aplica escopo, altera versao, cancela lembretes e publica evento |
| `Calendar::CancelAppointmentsService` | cancela uma, futuras ou toda serie com motivo |
| `Calendar::CompleteAppointmentService` | conclui ou marca falta sem apagar historia |
| `Calendar::GenerateSeriesService` | gera previa e ocorrencias para frequencia configurada |
| `Calendar::SyncLegacyCardDateService` | espelha opcionalmente `starts_at` no campo legado definido pelo board |
| `Calendar::ExternalSyncService` | futuro adaptador por provedor, nunca chamado pelo controller |

Controllers ficam finos e chamam servicos. Eventos sao publicados somente depois do commit.

## Rotas P0

Todas abaixo ficam sob `api/v1/accounts/:account_id` e exigem escopo de conta/policy.

| Metodo | Rota | Uso |
| --- | --- | --- |
| `GET` | `/calendar/appointments` | grade por periodo, recurso, status e busca |
| `POST` | `/calendar/appointments/availability` | slots por procedimento/recurso/data |
| `POST` | `/calendar/appointments` | marcar unica ou serie |
| `GET` | `/calendar/appointments/:id` | drawer de detalhe |
| `PATCH` | `/calendar/appointments/:id` | confirmar, concluir, falta, nota permitida |
| `POST` | `/calendar/appointments/:id/reschedule` | reagendar escopo escolhido |
| `POST` | `/calendar/appointments/:id/cancel` | cancelar escopo escolhido |
| `GET/POST/PATCH` | `/calendar/procedures` | configuracao de procedimento |
| `GET/POST/PATCH` | `/calendar/resources` | recursos e disponibilidade |

Criacao recebe `lock_version` quando atualiza uma ocorrencia. Resposta de conflito e `409` com recurso e intervalo em conflito; resposta de regra invalida e `422` com erros por campo.

## Politica De Serie

`scope` em reagendamento/cancelamento:

- `this_occurrence`;
- `this_and_future`;
- `all_occurrences`.

`this_and_future` nao move registros historicos. Ele fecha a serie antiga depois da ocorrencia anterior e cria uma nova serie derivada, com novo padrao e referencias de auditoria. Assim uma sessao ja realizada nunca muda de data retroativamente.

Para `all_occurrences`, ocorrencias concluidas, faltas e canceladas permanecem imutaveis; a operacao afeta apenas ocorrencias ativas e futuras.

## Eventos E Automacoes

O listener publica payload minimo:

```json
{
  "account_id": 1,
  "board_id": 4,
  "card_id": 91,
  "appointment_id": 301,
  "series_id": 22,
  "procedure_id": 6,
  "status": "scheduled",
  "starts_at": "2026-08-12T13:00:00Z",
  "timezone": "America/Sao_Paulo",
  "appointment_version": 1,
  "occurred_at": "2026-08-06T15:00:00Z"
}
```

No reagendamento, o cancelador de entregas procura `appointment_id + appointment_version`. O novo evento agenda apenas lembretes associados a versao nova. As automacoes usam `appointment.starts_at`, nao um campo manual do card.

## Politicas E Permissoes

Novas permissoes comerciais:

- `calendar_view`;
- `calendar_create`;
- `calendar_edit`;
- `calendar_cancel`;
- `calendar_configure`;
- `calendar_view_sensitive_notes`.

O escopo combina recurso, board e inbox quando houver oportunidade. Administrador da conta nao ignora isolamento de outra conta. Uma secretaria pode ver somente o recurso/unidade concedidos.

## Frontend P0

Componentes propostos:

- `CalendarWorkspace`;
- `CalendarToolbar`;
- `CalendarMonthGrid`, `CalendarWeekGrid` e `CalendarDayGrid`;
- `CalendarResourceSelector`;
- `CalendarAppointmentBlock`;
- `CalendarAppointmentDrawer`;
- `CalendarBookingComposer`;
- `CalendarSeriesPreview`;
- `CalendarProcedureSettings`;
- `CalendarResourceSettings`.

Usar Vue 3 Composition API e componentes pequenos. A grade nao deve levar formulários embutidos. Drag abre confirmacao de reagendamento; alternativa de teclado inclui menu `Reagendar` no drawer. Cada bloco possui rotulo acessivel com horario, contato, procedimento e status.

## Integracao Google Calendar Posterior

Tabela futura `CalendarExternalConnection` guarda credencial cifrada, `provider`, `calendar_id`, `resource_id`, `sync_token`, estado e ultimo erro. Tabela `CalendarExternalEvent` mapeia `appointment_id`, `provider`, `external_event_id`, `etag` e `last_synced_at`.

Fases obrigatorias:

1. exportacao unilateral, criada por job apos commit;
2. sincronizacao inicial, persistindo `nextSyncToken`;
3. sincronizacao incremental com o mesmo conjunto de parametros;
4. tratamento de token invalido com ressincronizacao completa;
5. conciliacao por `etag`, versao local e politica explicita de conflito;
6. tela de diagnostico, reprocessamento e desconexao.

Nao implementar bidirecional sem esses seis itens. O Google Calendar exige timezone para recorrencias e pode devolver instancias canceladas com dados limitados; por isso a base local deve manter historia completa.

## Testes De Aceite

### Backend

- cria consulta unica em horario livre;
- recusa duas reservas concorrentes do mesmo recurso;
- aceita recursos diferentes no mesmo horario;
- cria serie semanal de dez ocorrencias no fuso correto;
- reagenda somente uma ocorrencia;
- divide serie em `esta e futuras` sem alterar historico;
- cancela futuras e preserva concluidas;
- cancela lembretes pendentes e cria novos no reagendamento;
- rejeita acesso entre contas/recursos sem permissao;
- trata transicao de horario de verao com timezone IANA;
- nao inclui nota em evento/webhook externo.

### Frontend E2E

- criar pela conversa, card e pagina Agenda;
- navegar por dia/semana/mes, recurso e status;
- buscar por contato, telefone e oportunidade;
- criar serie, revisar previa e confirmar;
- reagendar por drawer, menu e drag com confirmacao;
- cancelar e marcar falta;
- foco, Escape, tabulacao, leitor de tela e alternativa sem drag;
- erro `409` preserva dados e mostra conflito acionavel;
- dois agentes editando a mesma ocorrencia recebem resolucao compreensivel.

O roteiro `tests/playwright/tests/e2e/ui/calendar-workspace.spec.ts` cobre no desktop: abertura por teclado, filtros, visoes Dia/Semana/Mes, criacao a partir de horario livre, abertura de detalhe, retorno de foco no fechamento, remarcacao e cancelamento justificado. O compositor tambem possui teste de componente para conflito `409`: preserva o formulario, comunica indisponibilidade e recarrega horarios livres.

Para executar a validacao integrada, prepare uma conta de homologacao com o procedimento `Consulta E2E`, o recurso ativo `Dra. E2E`, disponibilidade semanal e o contato `Paciente E2E`. Para os cenarios de detalhe, defina tambem o contato de uma consulta existente em `CALENDAR_E2E_APPOINTMENT_CONTACT`. Nenhum dado sensivel deve ser usado.

```bash
cd tests/playwright
BASE_URL=http://localhost:3000 \
TEST_USER_EMAIL=admin@chatwoot.com \
TEST_USER_PASSWORD='<senha-da-conta-de-homologacao>' \
CALENDAR_E2E=1 \
CALENDAR_E2E_APPOINTMENT_CONTACT='Paciente E2E' \
pnpm playwright:run tests/e2e/ui/calendar-workspace.spec.ts
```

## Plano De Entrega

### Fase A: Fundacao

- [x] migrations, modelos, policies e auditoria de criacao;
- [x] catalogo e endpoints iniciais de procedimentos e recursos;
- [x] reserva unica com exclusao de conflito PostgreSQL;
- [x] disponibilidade semanal e excecoes por data;
- [x] consulta de slots por procedimento/recurso/data;
- [x] teste de concorrencia real com duas transacoes simultaneas.

### Fase B: Operacao

- [x] pagina Agenda dia/semana/mes;
- [x] compositor pela conversa/card/agenda;
- [x] drawer de detalhe, confirmar, concluir, falta e cancelar;
- [x] configuracao e edicao de procedimentos e recursos.

### Fase C: Series E Automacoes

- [x] previa e geracao de serie;
- [x] reagendar/cancelar por escopo;
- [x] adaptador de lembretes para ocorrencia;
- [x] compatibilidade opcional com campo legado do card.

### Fase D: Qualidade E Integracoes

- [ ] E2E desktop, teclado e acessibilidade: desktop e teclado cobertos; mobile e leitor de tela ainda pendentes;
- [ ] carga, concorrencia e smoke de migration;
- [ ] Google Calendar unilateral;
- [ ] sincronizacao bidirecional somente apos auditoria da fase anterior.
