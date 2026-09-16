# SPEC — Configurações da agenda e página de agendamento

Como construir o que o [`raevo-agenda-prd.md`](raevo-agenda-prd.md) descreve, com
o visual dos dois mockups aprovados:

- Configurações — https://claude.ai/code/artifact/a5142472-d7f9-4c14-b49b-13b55c5257fa
- Página pública — https://claude.ai/code/artifact/d0ca7c0c-ab23-4241-b668-bd51ca16b060

Escrito contra o código em `deploy/custom-whatsapp-kanban` no commit `e0e026f9d`.

---

## 0 · Traduzir o mockup sem o desfigurar

Os mockups foram escritos em HTML solto, com cor e medida literais. No produto
isso é proibido pelas sete regras do [`CLAUDE.md`](../CLAUDE.md). A tradução é
mecânica e está fixada aqui para que ninguém a improvise.

### 0.1 · Cor

| No mockup | No produto | Nota |
| --- | --- | --- |
| `--brand #2563EB` | `n-brand` / `--raevo-brand` | já é o azul da primeira etapa do funil |
| `--teal #0F9D8F` | token de sucesso (`--raevo-success`) | é a cor da etapa Ganho |
| `--amber #B45309` | token de aviso (`--raevo-warning`) | |
| `--violet #A21CAF` | `raevoPalette` | só no cartão «o que é nosso» e no selo Feegow |
| `--ink / --ink-soft / --ink-faint` | `n-slate-12 / n-slate-11 / n-slate-10` | |
| `--line / --line-strong` | `n-strong` / `n-weak` conforme o uso | |
| `--ground / --surface / --surface-2` | `n-background` / `n-solid-1` / `n-solid-2` | |

Se faltar token, cria-se em `_raevo-tokens.scss`. **Nunca no componente.**

### 0.2 · Tipografia

O mockup usa sete tamanhos (11, 12, 13, 14, 17, 19, 25). A escala do Raevo tem
seis degraus e **13, 17, 19 e 25 não existem nela**. Mapa obrigatório:

| Mockup | Produto |
| --- | --- |
| 11px (caixa alta, selo) | `text-micro` |
| 12px | `text-xs` |
| 13px (corpo de linha, campo, chip) | `text-sm` |
| 14px (título de grupo, nome) | `text-sm` com `font-semibold` |
| 17–19px (título do painel) | `text-xl` |
| 25px (título da página) | `text-3xl` |

**Substituído pela decisão D7 (2026-09-16): o visual é igual ao mockup.** O corpo
fica em 13 px com um degrau novo `text-ui` (13/18 px) em `tailwind.config.js`;
17 px → `text-lg`, 19 px → `text-xl`, 25 px → `text-2xl`. Tabela completa, com a
diferença de cada um, no documento
[Nova agenda do Raevo — PRD e SPEC](https://claude.ai/code/artifact/ccfe19fc-db68-4f26-b6a0-440ca1fda124),
secção «Fidelidade visual», que é a versão de referência.

### 0.3 · Forma

**Decisão D7: onde o mockup difere do sistema de design, vence o mockup**, sem
valor literal no componente:

1. **Campo de uma linha com canto de 10 px**, não pílula: variante `compact` do
   `RaevoField` (`h-9 rounded-lg`), criada em `components-next/raevo/raevoControl.js`
   e usada só nestas telas. Botões, chips e selos continuam pílula, como no mockup.
2. **Campo é sempre `RaevoField`** — rótulo acima, campo abaixo, mesma borda.
   Nunca `<label>` + `<input>` com classe própria.
3. **Sem sombra dentro da tela.** A moldura do mockup (`box-shadow: 0 14px 34px…`)
   e os três pontos cinzentos são cenário de apresentação e não entram.

Tudo o resto — a divisão em colunas, as medidas de coluna, o espaçamento, a
ordem dos campos, os textos, os estados — entrega-se tal como está no mockup.

### 0.4 · Estado nunca só por cor

Os selos do mockup («padrão», «em uso», «falta horário», «Google», «Feegow») já
têm texto. Os que só tinham cor ganham ícone Lucide: `falta horário` →
`triangle-alert`, `Google` → `calendar`, `Feegow` → `stethoscope`.

---

## 1 · Modelo de dados

Quatro migrations. Nenhuma apaga dado de cliente.

### 1.1 · `kanban_calendar_schedules` — horário com nome

```ruby
create_table :kanban_calendar_schedules do |t|
  t.references :account, null: false, foreign_key: true, index: true
  t.references :kanban_calendar_procedure, foreign_key: true  # presente = horário privado de um procedimento
  t.string  :name, null: false
  t.string  :timezone, null: false
  t.boolean :default_schedule, null: false, default: false
  t.timestamps
end
add_index :kanban_calendar_schedules, 'account_id, lower(name)',
          unique: true, where: 'kanban_calendar_procedure_id IS NULL',
          name: :index_calendar_schedules_on_account_and_lower_name
add_index :kanban_calendar_schedules, :account_id,
          unique: true, where: 'default_schedule = true',
          name: :index_calendar_schedules_on_account_default
```

`KanbanCalendarSchedule` valida fuso IANA (igual a `KanbanCalendarResource`),
`has_many :kanban_calendar_availability_rules`, `has_many :kanban_calendar_resources`.
Um horário com procedimento não aparece na lista de Disponibilidade.

### 1.2 · Regras passam a pertencer ao horário

```ruby
add_reference :kanban_calendar_availability_rules, :kanban_calendar_schedule, foreign_key: true
change_column_null :kanban_calendar_availability_rules, :kanban_calendar_resource_id, true
add_check_constraint :kanban_calendar_availability_rules,
  '(kanban_calendar_schedule_id IS NULL) <> (kanban_calendar_resource_id IS NULL)',
  name: :calendar_rule_belongs_to_one_owner
add_reference :kanban_calendar_resources, :kanban_calendar_schedule, foreign_key: true
```

**Quem fica onde:** `weekly_window` e `date_override` passam para o horário;
`block` (bloqueio pontual de uma agenda) fica na agenda, porque é sempre de uma
agenda só.

**Backfill, na mesma migration, idempotente:** para cada
`KanbanCalendarResource` com regras semanais, criar
`KanbanCalendarSchedule.new(name: "Horário de #{resource.name}", timezone: resource.timezone)`,
mover as regras `weekly_window`/`date_override` para ele e apontar
`resource.kanban_calendar_schedule_id`. Agendas idênticas **não** são fundidas:
juntar é decisão da clínica, não da migração (decisão 1 do PRD).

`KanbanCalendarResource#create_default_working_hours` passa a criar o horário
«Comercial» da conta, se ainda não existir, e a apontar para ele — a semana
08:00–18:00 de segunda a sexta continua a ser o que uma agenda nova ganha.

### 1.3 · O procedimento ganha o que hoje é da conta

```ruby
add_column :kanban_calendar_procedures, :availability_mode, :string, null: false, default: 'resources'
add_reference :kanban_calendar_procedures, :kanban_calendar_schedule, foreign_key: true
add_reference :kanban_calendar_procedures, :kanban_calendar_team, foreign_key: true
add_column :kanban_calendar_procedures, :assignment_strategy, :string, null: false, default: 'patient_choice'
add_column :kanban_calendar_procedures, :minimum_notice_minutes, :integer
add_column :kanban_calendar_procedures, :maximum_notice_days, :integer
add_column :kanban_calendar_procedures, :slot_interval_minutes, :integer
add_column :kanban_calendar_procedures, :daily_limit, :integer
add_column :kanban_calendar_procedures, :payment_enabled, :boolean, null: false, default: false
add_column :kanban_calendar_procedures, :price_cents, :integer
add_column :kanban_calendar_procedures, :payment_mode, :string, null: false, default: 'full'
add_column :kanban_calendar_procedures, :deposit_cents, :integer
add_column :kanban_calendar_procedures, :payment_methods, :jsonb, null: false, default: %w[pix card on_site]
add_column :kanban_calendar_procedures, :hold_minutes, :integer, null: false, default: 10
add_column :kanban_calendar_procedures, :reschedule_allowed, :boolean, null: false, default: true
add_column :kanban_calendar_procedures, :cancel_allowed, :boolean, null: false, default: true
add_column :kanban_calendar_procedures, :change_deadline_hours, :integer, null: false, default: 12
add_column :kanban_calendar_procedures, :cancel_reason_required, :boolean, null: false, default: true
add_column :kanban_calendar_procedures, :on_cancel_stage_action, :string, null: false, default: 'back_to_scheduling'
```

Enums e validações no modelo:

- `availability_mode`: `resources` (cruza o horário de cada agenda) · `schedule`
  (um horário nomeado, ainda cruzado com as ocupações das agendas).
  O «horário só deste procedimento» do mockup é `schedule` com um
  `KanbanCalendarSchedule` cujo `kanban_calendar_procedure_id` é este.
- `assignment_strategy`: `patient_choice` · `first_available` · `round_robin` ·
  `collective`. Só `patient_choice` e `collective` são válidos sem equipe.
- `payment_mode`: `full` · `deposit`; `deposit_cents` obrigatório e menor que
  `price_cents` quando `deposit`; `price_cents` obrigatório quando
  `payment_enabled`.
- `payment_methods`: subconjunto não vazio de `pix card on_site`.
- `minimum_notice_minutes`, `maximum_notice_days`, `slot_interval_minutes` e
  `daily_limit` **nulos significam «o padrão da conta»**, que continua a vir de
  `KanbanCalendarBookingPage` — o mesmo padrão que `slot_interval_minutes` já
  usa na agenda.
- `on_cancel_stage_action`: `back_to_scheduling` · `mark_lost` · `none`.

**Perguntas do formulário** vão para o `public_booking_config` que já existe:

```json
{ "questions": [
  { "key": "full_name", "label": "Nome completo", "kind": "text", "required": true, "locked": true },
  { "key": "whatsapp",  "label": "WhatsApp",      "kind": "phone", "required": true },
  { "key": "cpf",       "label": "CPF",           "kind": "cpf",  "required": "feegow" },
  { "key": "email",     "label": "E-mail",        "kind": "email", "required": false },
  { "key": "notes",     "label": "Algo que a equipe deva saber?", "kind": "textarea", "required": false }
] }
```

`kind` ∈ `text phone email cpf textarea select date`. `required: "feegow"` é o
terceiro estado do mockup: obrigatório **apenas** quando alguma agenda do
procedimento está mapeada em `settings['feegow']['professional_id']` — a regra
combinada na fase 1 do Feegow. `locked: true` é o «fixo» do mockup: nome
completo não se apaga nem se torna opcional.

### 1.4 · Equipes

```ruby
create_table :kanban_calendar_teams do |t|
  t.references :account, null: false, foreign_key: true, index: true
  t.string  :name, null: false
  t.string  :assignment_strategy, null: false, default: 'first_available'
  t.boolean :active, null: false, default: true
  t.timestamps
end
add_index :kanban_calendar_teams, 'account_id, lower(name)', unique: true

create_table :kanban_calendar_team_members do |t|
  t.references :kanban_calendar_team, null: false, foreign_key: true
  t.references :kanban_calendar_resource, null: false, foreign_key: true
  t.boolean  :active, null: false, default: true
  t.datetime :last_assigned_at
  t.timestamps
end
add_index :kanban_calendar_team_members,
          %i[kanban_calendar_team_id kanban_calendar_resource_id], unique: true,
          name: :index_calendar_team_members_on_team_and_resource
```

Membro tem de ser `resource_type: 'user'` da mesma conta.
`last_assigned_at` é o que faz o rodízio: escolhe-se o membro livre com o
`last_assigned_at` mais antigo, e grava-se no momento em que a consulta é criada.

### 1.5 · Reserva temporária e fuso do paciente

```ruby
add_column :kanban_calendar_appointments, :hold_expires_at, :datetime
add_column :kanban_calendar_appointments, :booking_timezone, :string
add_index  :kanban_calendar_appointments, :hold_expires_at, where: 'hold_expires_at IS NOT NULL'
add_column :kanban_calendar_booking_pages, :clinic_name, :string
add_column :kanban_calendar_booking_pages, :clinic_address, :string
```

`KanbanCalendarAppointment` ganha o estado **`hold`** na sua lista de estados.
Uma consulta em `hold` **ocupa horário** (entra em
`AvailabilityCheckService`) e **não** aparece na grade da agenda nem no funil.
`ExpireCalendarHoldsJob` corre no `TriggerScheduledItemsJob` (5 min) e apaga as
que passaram do `hold_expires_at`. Sem cobrança, o `hold` dura o tempo de
preencher o formulário; com cobrança, até o webhook confirmar ou expirar.

---

## 2 · Serviços

| Serviço | Mudança |
| --- | --- |
| `AvailabilitySlotsQuery` | janelas passam a vir do horário do procedimento quando `availability_mode == 'schedule'`, senão do horário de cada agenda; `slot_interval_minutes` ganha o degrau do procedimento antes do da agenda e do da conta |
| `AvailabilityAcrossResources` | novo `days_with_slots(from:, to:)` devolvendo só as datas que têm pelo menos um horário — é o que pinta o calendário do mês; e `resolve_resources(procedure:)` que expande a equipe conforme `assignment_strategy` |
| `AvailabilityCheckService` | conta consultas em `hold` como ocupadas |
| `BookAppointmentService` | aceita `hold_minutes` e `booking_timezone`; grava `last_assigned_at` no membro quando a estratégia é `round_robin` |
| `PublicBookingService` | passo em dois tempos: `hold!` cria a consulta em `hold`, `confirm!` promove a `scheduled` (ou deixa em `hold` até o webhook, com cobrança) |
| **novo** `KanbanCalendar::ScheduleApplier` | aplicar um horário a N agendas numa transação |
| **novo** `KanbanCalendar::TeamAssignment` | devolve o membro para um intervalo, segundo a estratégia |
| **novo** `KanbanCalendar::ProcedureLimits` | resolve limite efetivo (procedimento → página → omissão) num sítio só |

**Ordem de precedência, escrita uma vez e usada em todo o lado:**
procedimento → página de agendamento da conta → omissão do código.

### 2.1 · Pagamento

Segue as regras do Financeiro no `CLAUDE.md`, sem exceção:

- `FinancePayment` é a fonte de verdade. Redirecionamento do browser **não**
  confirma nada.
- Com `payment_enabled`, a reserva nasce em `hold` e só passa a `scheduled` no
  **webhook idempotente** do Asaas. A página pública faz *polling* do estado e
  mostra «aguardando confirmação do pagamento» até lá.
- `on_site` (pagar na clínica) confirma na hora: não gera cobrança.
- O valor cobrado é `price_cents` em `full`, `deposit_cents` em `deposit`, e o
  resto aparece como «na clínica» no resumo.

---

## 3 · API

### 3.1 · Painel (`/api/v1/accounts/:account_id/calendar`)

```
resources :schedules do
  put :rules, on: :member          # troca a semana inteira numa transação
  post :apply_to, on: :member      # {resource_ids: []}
end
resources :teams
get 'procedures/:id/availability_preview'   # ?days=14 → usa AvailabilityAcrossResources#upcoming
```

`ProceduresController` permite os novos parâmetros de 1.3, incluindo
`public_booking_config: { questions: [] }`.

Payload de `schedules#index`:

```json
[{ "id": 3, "name": "Manhãs da Dra. Anna", "timezone": "America/Recife",
   "default": false, "resources_count": 1,
   "weekly": [{ "weekday": 1, "ranges": [["08:00","12:00"]] }],
   "overrides": [{ "date": "2026-10-07", "closed": true },
                 { "date": "2026-10-12", "ranges": [["09:00","11:00"]] }] }]
```

`resources#index` passa a devolver `schedule: {id, name}` e
`missing_hours: true` quando não há janela nenhuma — é o selo «falta horário».

### 3.2 · Público (`/agendar/...`)

| Rota | Mudança |
| --- | --- |
| `GET /agendar/:token/:slug/disponibilidade?month=2026-09&tz=America/Recife` | **novo**: `{ "days": ["2026-09-16", …] }`, os dias acesos do calendário |
| `GET …/disponibilidade?date=…&tz=…` | igual, mas devolve os horários já no fuso pedido |
| `POST …/reservas` | ganha `hold: true` → `201 { hold_token, expires_at }` |
| `POST …/reservas/:hold_token/confirmar` | **novo**: confirma, ou devolve `payment: {url, status}` quando há cobrança |
| `GET …/reserva/:public_token/ics` | **novo**: «adicionar ao meu calendário» |

O limite de pedidos (`PublicBookingRateLimiter`), o `consent`, o campo-armadilha
`website` e o captcha continuam a valer, e passam a valer também no `hold` —
senão o `hold` vira uma forma de ocupar a agenda de graça.

---

## 4 · Frontend — configurações

Rota nova: `/app/accounts/:id/calendar/settings/:section`, com
`section ∈ procedimentos | disponibilidade | agendas | equipes`. O que hoje é
`CalendarSettingsView.vue` passa a ser a casca com a barra lateral do mockup.

```
calendar/
  CalendarSettingsView.vue        casca: rail 196px + conteúdo
  settings/
    ProcedureListView.vue
    ProcedurePanel.vue            tabs 210px + painel
    tabs/ProcedureSetupTab.vue
    tabs/ProcedureResourcesTab.vue     «Quem atende»
    tabs/ProcedureWhenTab.vue          «Quando» + prévia
    tabs/ProcedureFormTab.vue          perguntas
    tabs/ProcedureLimitsTab.vue
    tabs/ProcedurePaymentTab.vue
    tabs/ProcedureChangesTab.vue       remarcar e cancelar
    ScheduleListView.vue
    ScheduleEditor.vue                 semana + copiar para…
    ScheduleOverrides.vue              exceções de data
    ResourceListView.vue
    TeamListView.vue
```

### 4.1 · Medidas a respeitar (saem do mockup)

| Elemento | Medida |
| --- | --- |
| Barra lateral de secções | `196px`, fundo `n-solid-2`, borda à direita |
| Coluna de abas do procedimento | `210px`, item com título e legenda em duas linhas |
| Painel | `padding: 18px 20px`, `gap: 16px` entre grupos |
| Grupo | borda 1px, `rounded-xl`, cabeçalho com título à esquerda e legenda à direita |
| Linha de lista | `padding: 10px 0`, separador 1px, **sem** separador na última |
| Dois/três campos lado a lado | `grid 1fr 1fr` / `repeat(3,1fr)`, `gap: 12px`, uma coluna abaixo de 620px |
| Editor da semana | `110px` para o dia · intervalos · botão «copiar para…» |
| Abaixo de 860px | barra lateral e coluna de abas viram um seletor no topo |

Aba ativa: `aria-pressed="true"`, fundo `n-brand` a 12% e texto `n-brand` — como
no mockup, e com o rótulo sempre visível (nunca só cor).

### 4.2 · A prévia da aba «Quando»

Chama `availability_preview` e desenha os dias como o mockup: data à esquerda,
agendas em legenda, horários como chips. É a mesma lista que a página pública
mostra — **é o teste vivo da configuração**, e por isso não pode usar outro
caminho de código que não `AvailabilityAcrossResources`.

### 4.3 · Interações obrigatórias

- **Copiar para…** abre a lista dos dias da semana com caixas de seleção.
- **Aplicar a agendas** no editor de horário chama `apply_to`.
- Trocar o horário de uma agenda que está a ser usada avisa quantas consultas
  futuras ficam fora da nova janela — avisa, não impede.
- Cada gesto de arrastar (se houver) tem alternativa por teclado. O editor da
  semana é todo por botão e campo; não introduzir arrastar aqui.

---

## 5 · Frontend — página de agendamento

`app/javascript/public_booking/PublicBookingApp.vue` passa a orquestrar quatro
componentes; a lógica de disponibilidade fica num composable.

```
public_booking/
  PublicBookingApp.vue      passos e estado
  BookingAside.vue          clínica, procedimento, meta, aviso
  BookingPicker.vue         passos, procedimentos, calendário do mês
  BookingTimes.vue          horários do dia + fuso
  BookingForm.vue           perguntas + pagamento
  BookingDone.vue           confirmação, .ics, remarcar
  useBookingAvailability.js
```

### 5.1 · Grade

```
passo 1:  300px | 1fr | 210px      (.booking.wide do mockup)
passo 2:  300px | 1fr
passo 3:  uma coluna, centrada
abaixo de 900px: uma coluna
```

### 5.2 · Calendário do mês

- Sete colunas, `gap: 5px`, célula `aspect-ratio: 1`, `rounded-lg`.
- **Dia com vaga:** fundo `n-solid-2`, borda `n-weak`, número em `n-slate-12`,
  peso 600, clicável.
- **Dia sem vaga:** transparente, número em `n-slate-10`, `cursor: default`,
  `aria-disabled`, e **continua visível** — o mockup não os esconde.
- **Dia escolhido:** `n-brand` cheio, número branco, `aria-pressed`.
- Abaixo: «Dias sem destaque não têm vaga para esta combinação».
- Setas `‹` `›` com `aria-label`; teclado navega com as setas do teclado.

### 5.3 · Horários

Coluna de 210px: título com o dia por extenso, «N horários livres», botões de
largura cheia com `font-variant-numeric: tabular-nums`, e o seletor de fuso com
o globo. O fuso arranca no do visitante (`Intl.DateTimeFormat().resolvedOptions().timeZone`)
e o escolhido vai no `POST` como `booking_timezone`.

### 5.4 · Formulário

Campos vêm de `public_booking_config.questions`, na ordem gravada, em
`RaevoField`. CPF só aparece quando `required == 'feegow'` e o procedimento
espelha no Feegow, com máscara e validação de dígito.

Bloco de pagamento: borda esquerda de 3px na cor de sucesso, linhas
procedimento/forma/total, formas como chips (`aria-pressed`), total em
`tabular-nums`. Com `payment_enabled == false` o bloco e o preço somem e o botão
diz **«Confirmar agendamento»** em vez de **«Pagar e confirmar»** — os dois
estados do interruptor do mockup.

Enquanto se preenche: «Enquanto você preenche, o horário fica reservado por N
minutos», com N de `hold_minutes`, e um contador visível quando faltar menos de
um minuto.

### 5.5 · Confirmação

Marca de visto, «Consulta marcada», a frase com dia, hora, profissional e sala,
o resumo em três linhas (data/hora com fuso, endereço, pagamento) e os dois
botões: **adicionar ao meu calendário** (baixa o `.ics`) e **remarcar** (leva ao
link de remarcação, se `reschedule_allowed`).

Com Pix ainda por confirmar, o passo 3 mostra **«aguardando confirmação do
pagamento»** com o código, e só vira «Consulta marcada» quando o webhook chegar.
Nunca se afirma pagamento por causa de um redirecionamento.

---

## 6 · Ordem de entrega

Cada fase é subível sozinha e não parte a anterior.

| Fase | O que entra | Por que é primeiro |
| --- | --- | --- |
| **1** | Horários nomeados: tabelas, backfill, tela de Disponibilidade, escolha na agenda, exceções de data | é a fundação; sem isto as outras telas não têm o que mostrar |
| **2** | Casca das configurações (barra lateral + painel de abas), telas de Agendas e Procedimentos com «O que é», «Quem atende», «Quando» e a prévia | é a maior parte do mockup 1 |
| **3** | Limites e formulário por procedimento | destrava as regras que hoje são da conta inteira |
| **4** | Equipes e estratégias de distribuição | |
| **5** | Página pública nova: aside, calendário do mês, horários, fuso, formulário, confirmação, `.ics` | mockup 2, sem pagamento |
| **6** | `hold`, pagamento, remarcar e cancelar pelo paciente | depende do Financeiro e é o mais arriscado |

---

## 7 · Verificação

Cada fase fecha com a Porta de Qualidade Visual inteira (`CLAUDE.md`), não com
testes unitários apenas. Três defeitos desta semana — a lista de etapas que
partia, a barra de gravar que fugia do clique e a agenda sem horário que não
oferecia nada — passaram pelos testes e só a jornada real os apanhou.

- `bundle exec rspec spec/models/kanban_calendar* spec/services/kanban_calendar spec/requests/api/v1/accounts/calendar spec/requests/public/calendar_bookings_spec.rb`
- `npx vitest run` nas telas de agenda e no `public_booking`
- Jornada de browser a 1280px com screenshot antes/depois, incluindo erro e
  recuperação (horário que some entre escolher e confirmar → `409` com recado)
- `TZ=UTC` na suite: a agenda já partiu uma vez no CI por causa disso
- `pnpm raevo:design`, `pnpm eslint`, `bundle exec rubocop`, i18n só em
  `en.json`/`en.yml`

### Casos que têm de estar cobertos

1. Horário aplicado a quatro agendas; mudar o horário muda as quatro.
2. Exceção «fechado» tira o dia da página pública sem tocar na semana.
3. `minimum_notice_minutes` do procedimento vence o da conta; nulo cai no da conta.
4. Prévia da aba «Quando» e página pública devolvem a mesma lista.
5. Rodízio alterna entre dois profissionais livres; `collective` só oferece o
   que ambos têm livre.
6. `hold` ocupa horário para outro visitante e desaparece ao expirar.
7. Com Pix pendente, a consulta **não** fica `scheduled` sem webhook.
8. Consulta vinda do Feegow (`source_read_only`) continua intocável.
9. Agenda sem janela nenhuma mostra «falta horário» e não oferece horário.
10. Calendário do mês não acende dia que o Google ou o Feegow ocuparam por inteiro.
