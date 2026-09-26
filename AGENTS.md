# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
(Note: `CLAUDE.md` is a symlink to `AGENTS.md` — edit this file to update both.)

# Raevo Design System — LEIA ANTES DE MEXER EM QUALQUER UI

Este fork é o **Raevo**. A direção é **A · Consultório**, aprovada a 19/09/2026 e
migrada para o código a 21/09/2026. Durante três semanas houve duas em jogo — o
código em H · Sereno e Consultório só como alvo gravado — e a tabela que as separava
já não é precisa: **o código é a direção aprovada.**

O que isso quer dizer na prática: a ação é quase preta (`#171717`), a base é
acromática, o controlo tem 10px de raio e o primário **inverte** para `#E5E5E5` no
escuro. Ver [`design-system/aprovado/README.md`](design-system/aprovado/README.md)
para as sete decisões e de onde veio cada valor.

- **Tela nova, componente novo, diálogo novo → nasce em Consultório.** O sistema está
  gravado em [`design-system/aprovado/`](design-system/aprovado/README.md).
- **Tela que já existe → não muda sem aprovação.** A fila e o processo estão em
  [`docs/raevo-aprovacao.md`](docs/raevo-aprovacao.md). Implementar antes de aprovar é
  retrabalho à espera de acontecer.
- **Tela nativa do Chatwoot** (Conversas, Contactos, Definições, Caixas de entrada,
  Central de ajuda) → **só tokens, markup intocado**. Herda a identidade sem ser
  editada. Redesenhá-las tela a tela é o que encarece cada `git pull` do upstream.

**Especificação completa e obrigatória: [`docs/raevo-design-system.md`](docs/raevo-design-system.md).**
Leia antes de escrever CSS ou markup. As regras abaixo são o resumo executável.

## Toda mudança de UI passa pelo design system — e por esta ordem

Não é conselho: é a sequência de trabalho. **Antes** de escrever markup, e **outra vez** antes
de abrir PR.

1. **Já existe primitivo?** `components-next/raevo/` — `RaevoPageHeader`, `RaevoKpiCard`,
   `RaevoStamp`, `RaevoField`. Se existe, usa-se; não se recria nem se desenha à mão. Foi por
   se ter recriado que o produto chegou a três tratamentos de cartão de número e a três de
   campo dentro do mesmo diálogo.
2. **O padrão está escrito?** `docs/raevo-design-system.md` §5 tem cabeçalho de página,
   indicador (as três densidades), card de lead, tabela, coluna do funil, estado de consulta.
   Cor no §2, forma no §3, tipografia no §4.
3. **O valor está gravado?** `design-system/raevo.tokens.json` é o sistema como está no código
   e `design-system/aprovado/consultorio.tokens.json` é a direção aprovada. Token que falta
   nasce em `_raevo-tokens.scss`, nunca no componente.
4. **A tela já existe?** Então não muda sem passar por
   [`docs/raevo-aprovacao.md`](docs/raevo-aprovacao.md) — e a decisão fica lá escrita, com o
   que se ganhou e o que se perdeu.
5. **As portas correm** (`pnpm raevo:design`, `raevo:tokens`, `raevo:palette`) e a **porta
   visual** de cinco passos, com jornada real e capturas antes/depois.

**Ordem de precedência quando as fontes divergirem**, porque divergem:

| | |
| --- | --- |
| **1. O código** | `_raevo-tokens.scss`, `tailwind.config.js`, `components-next/raevo/`. É o que o utilizador vê e o que as portas medem |
| **2. `design-system/`** | os tokens gravados. `pnpm raevo:tokens` falha se o código divergir deles — é essa falha que os mantém honestos |
| **3. `docs/`** | a especificação e a fila de aprovação. Explicam o porquê; o valor está acima |
| **4. Os artefactos** | o demonstrador e a referência navegável no claude.ai são **espelhos para humanos**. Nunca são fonte: um token muda no código e o artefacto fica desactualizado sem ninguém dar por isso |

**Mudou alguma coisa nas três primeiras? Actualize também o artefacto**, na mesma passagem. Um
espelho desactualizado é pior do que nenhum, porque alguém desenha a partir dele.

## O que Consultório mudou em relação a Sereno

Histórico, para quem encontrar código ou capturas antigas. **Já está aplicado** — não
é uma migração por fazer.

| Decisão | Sereno | Consultório |
| --- | --- | --- |
| Cor de ação (`--brand-color`) | `#2563EB` | **`#171717`** — o azul fica só para etapa |
| Base | ardósia fria | **acromática** (croma zero) |
| Raio do controlo | pílula | **10px** (regra 4 abaixo) |
| Raio do cartão | 13px | 14px (`--radius` + 4) |
| Separação em repouso | espaço | **anel de 1px** (`ring-foreground/10`) |
| Modo escuro | invertido à mão | medido da referência; o primário **inverte** para `#E5E5E5` |
| Tipografia | seis degraus | **os mesmos seis degraus** — não muda nada |
| Paleta de etapas | travada | **travada, igual** |

O modo escuro **usa o interruptor de tema que o Chatwoot já tem**. Não se cria outro, e
a proposta C · Órbita não é o modo escuro de A — ver `docs/raevo-aprovacao.md`.

## As sete regras

1. **Nunca escreva cor, raio, sombra ou fonte literal.** Nada de `bg-[#2563EB]`,
   `style="color:#111"`, `border-radius: 8px`. Use as classes `n-*` do Tailwind e os
   tokens `--raevo-*`. Se falta um token, crie em
   `app/javascript/dashboard/assets/scss/_raevo-tokens.scss` — nunca no componente.
   Depois rode `pnpm raevo:tokens:extract`, senão a porta acusa divergência.

2. **Nunca edite `_next-colors.scss`, e não mude cor em `theme/colors.js`.** São arquivos
   upstream; editá-los gera conflito em todo `git pull` do Chatwoot. A identidade vive em
   `_raevo-tokens.scss`, que é importado depois e vence na cascata.

3. **`shadow-sm` é `none` de propósito.** Em repouso o espaço separa, não a sombra. Sombra
   só para o que realmente flutua: modal, menu, drawer (`shadow-lg`).

4. **Botão e campo usam `rounded-lg` (10px). Card e painel usam `rounded-xl` (14px).**
   Textarea e item de lista usam `rounded-md` (8px). O raio sai de uma fórmula sobre
   `--radius = 10px`, não de gosto: `sm` = base−4, `md` = base−2, `lg` = base,
   `xl` = base+4.

   **A pílula (`rounded-full`) fica para o selo e para a barra de pesquisa**, e mais
   nada. Era o padrão global em Sereno; deixou de ser a 21/09. A densidade alta tira
   largura ao controlo, e dois botões-pílula adjacentes ficam ambíguos.

5. **Estado nunca se comunica só por cor.** Sempre cor + ícone + texto. É requisito de
   acessibilidade (WCAG 2.2), não preferência estética.

6. **Tipografia só na escala.** (A migração para Consultório **não lhe tocou**: a
   referência não redefine um único degrau de tipo — a densidade dela vem da caixa,
   não do tipo.) Seis degraus: `text-micro` (11px, piso, só caixa alta e
   número curto) · `text-xs` (12) · `text-sm` (14) · `text-base` (16) · `text-xl` (20) ·
   `text-3xl` (30). **Nunca `text-[Npx]`** — a auditoria achou 27 degraus distintos em uso
   porque cada tela inventou o seu. Ver `docs/raevo-design-system.md` §4.

7. **Campo de formulário é sempre `RaevoField`.** Nunca escreva `<label>` + `<input>` com
   classe própria: foi assim que o produto acumulou 3 tratamentos de campo dentro do mesmo
   diálogo. Rótulo acima, campo abaixo, mesma borda esquerda. A aparência vem de
   `components-next/raevo/raevoControl.js` — se ela não serve, mude lá, não no template.

   ```vue
   <RaevoField :label="t('X.PROCEDIMENTO')" variant="select">
     <template #default="{ controlClass, fieldId }">
       <select :id="fieldId" v-model="x" :class="controlClass">…</select>
     </template>
   </RaevoField>
   ```

   Em `shallowMount`, `RaevoField` precisa de stub que renderize o slot com
   `control-class`/`field-id` — senão todos os campos somem do teste.

## Indicador: cartão onde é conteúdo, linha onde é contexto

`RaevoKpiCard` tem três densidades, e a escolha **não é gosto** — é a resposta a
«nesta tela o número é o assunto, ou é a moldura dele?», e a quanto espaço a
moldura tem direito.

| | Caixa | Número | Rodapé | Fila no Pipeline | Onde |
| --- | --- | --- | --- | --- | --- |
| `card` (omissão) | própria | 30px | sob filete | 139px | Início, Financeiro, IA |
| `strip` | nenhuma | 16px | por baixo | 76px | — |
| `inline` | nenhuma | 14px | **não há** | **28px** | Pipeline, Agenda |

`inline` é a única que **perde informação de propósito**: fica o rótulo, o valor e
o selo de variação, e o rodapé não é desenhado. É a troca que a faz caber no canto
de um cabeçalho que já existe.

**A exceção é a prop `note`**: um qualificador curto colado ao número, só em
`inline`, e só onde a variação não ocupa aquele lugar. Serve o caso em que o
rodapé levava a única coisa daquela fila sobre a qual se **age** — «3 por
confirmar», na Agenda, que não existe em mais lado nenhum do produto. Só aparece
quando tem o que dizer. **Uma nota por fila, no máximo:** cada uma custa largura,
e se a linha quebrar volta a ter duas alturas — que é o problema que ela resolve.

No Pipeline a linha mora no **canto inferior direito da caixa do cabeçalho**, e a
legenda de saúde das etapas vem **por baixo dela, também à direita**: a legenda
explica a barra das colunas, é apoio, e apoio vem depois do dado. Na Agenda, que
tem barra de uma linha e não caixa, a linha é a banda logo abaixo dela.

O selo de variação custa **1px** — cabe na linha do número. Medido: 27px sem ele,
28px com ele. Não é por espaço que se tira uma seta.

**Não desenhe uma linha de números à mão numa tela.** Foi por aí que o produto
chegou a três tratamentos de cartão de número; uma quarta variante inventada num
template é o mesmo erro com outro nome.

**Rodapé vazio em vez de «sem mês para comparar».** Numa conta nova três dos
quatro indicadores diziam isso. A ausência de seta já diz que não há base de
comparação. (Com `inline` a questão não se põe: não há rodapé.)

## Paleta de etapas do funil — travada

`#2563EB` `#0F9D8F` `#B45309` `#A21CAF` (+ `#98A0AE` para etapa terminal).

Validada para daltonismo: pior par ΔE 9,7 em deuteranopia. **Não troque sem revalidar:**

```bash
node scripts/validate_palette.js "#2563EB,#0F9D8F,#B45309,#A21CAF" --mode light --pairs all
```

Já reprovaram e estão proibidas: **azul + roxo claro** (ΔE 0,4) e a **paleta do Google
Calendar** (ΔE 3,4).

## Armadilha conhecida em testes

`shallowMount` stuba componentes filhos — inclusive `RaevoPageHeader`. O conteúdo dos slots
(`#actions`, `#filters`, `#tabs`) **desaparece** e testes que procuram botões do cabeçalho falham
com "Cannot call trigger on an empty DOMWrapper". Adicione o stub que renderiza slots:

```js
stubs: {
  RaevoPageHeader: {
    template:
      '<header><slot name="actions" /><slot name="filters" /><slot name="tabs" /><slot /></header>',
  },
}
```

O mesmo vale para **`RaevoKpiCard`**: stubado, engole rótulo, valor, variação e
rodapé, e a fila de quatro indicadores fica vazia no teste. O stub tem de declarar
os props e renderizá-los:

```js
RaevoKpiCard: {
  props: ['label', 'value', 'delta', 'footer', 'note'],
  template:
    '<div><i>{{ label }}</i><b>{{ value }}</b><s>{{ delta }}</s>' +
    '<u>{{ footer }}</u><em>{{ note }}</em></div>',
},
```

Exemplos prontos: `KanbanAutomations.spec.js`, `KanbanBoardSettings.spec.js`,
`FinanceView.spec.js`.

## Antes de abrir PR

```bash
pnpm raevo:design    # cor literal, tamanho fora da escala, E o par + a geometria
pnpm raevo:tokens    # falha se o código divergir do sistema gravado — inclui a direção aprovada
pnpm raevo:palette   # revalida a paleta de etapas
```

`raevo:design` corre **duas** verificações. A segunda
(`scripts/check-design-pairs.mjs`, também isolável em `pnpm raevo:pairs`) existe
porque as outras portas verificam o **valor** dos tokens e nunca o **par** que o
componente faz com eles — e foi por aí que passaram os dois piores defeitos que
este produto teve:

- O campo continuou pílula cinco meses depois de a regra 4 lhe dar 10px, porque a
  forma vivia numa constante de `raevoControl.js` — um `.js` que a porta nem lia.
- O botão primário ficou a **1,26:1** em modo escuro. Os dois tokens estavam
  certos; errado era juntá-los. `bg-n-brand` inverte para `#E5E5E5`, `text-white`
  não inverte.

Ela mede contraste nos dois modos com os valores que o browser resolve — a
cascata inteira, `_next-colors.scss` e `_raevo-tokens.scss` por cima — e recusa
o que reprova a WCAG 2.2 (4,5:1 para texto, 3:1 para texto grande e para
controlo só-de-ícone). Também recusa pílula em `<input>`, `<select>` e
`<textarea>` (a pesquisa é a exceção) e raio arbitrário `rounded-[Npx]`.

O que ela **não** vê está declarado no topo do próprio script. Leia antes de a
tomar por garantia.

Mexeu na direção aprovada? Não edite o JSON à mão: mude `scripts/author-consultorio.mjs`,
rode `pnpm raevo:aprovado` e leia o diff de `consultorio.tokens.json`.

As duas primeiras rodam em CI (`custom_checks.yml`, job `lint-frontend`) — e
`raevo:design` leva a verificação de pares consigo, sem mexer no workflow.

### Acrescentou um ficheiro de spec? Já não parte os shards dos outros

O `run_foss_spec` repartia os specs por `find spec | sort` e `indice % 16`. Um
ficheiro novo deslocava **todos** os que vinham depois dele em ordem alfabética
para o shard seguinte, e quem o acrescentou herdava o spec frágil de outra
pessoa, na sua PR, sem relação nenhuma com a sua mudança. Aconteceu cinco vezes
em dois PRs.

Desde 26/09 a repartição usa um **hash estável do caminho**: um ficheiro novo
muda de shard só a si — verificado, zero deslocamentos. O preço é o equilíbrio
por contagem de ficheiros ficar mais largo (40 a 56 por shard, contra 49–50
antes); em tempo de parede não se nota, porque o desequilíbrio já vinha da
duração dos specs e não da contagem.

**Isto não torna a suite independente de ordem, e não pode virar esconderijo.**
Quem caça as dependências de ordem é o `order_dependency_hunt.yml`: baralha os
ficheiros com uma semente, reparte, e corre cada pedaço com `--order random` na
mesma semente — varia agrupamento e ordem ao mesmo tempo, que é o que a estrada
das PRs não pode fazer. Corre à semana e a pedido; a semente vai no resumo do
trabalho, para se reproduzir. **Uma falha ali é um spec que depende de quem
correu antes — corrige-se o spec, nunca se desliga o teste.**

Mudou um token de propósito? Rode `pnpm raevo:tokens:extract` e **leia o diff do
JSON** — ele mostra tudo que a mudança moveu, inclusive o que você não pretendia.

## Onde a identidade mora

| Arquivo | Papel |
| --- | --- |
| `design-system/aprovado/consultorio.tokens.json` | **a direção aprovada** — o alvo de tudo o que for desenhado a partir de agora |
| `design-system/aprovado/README.md` | as sete decisões que Consultório trava, e de onde veio cada valor |
| `docs/raevo-aprovacao.md` | a fila de telas: o que precisa de aprovação, o que não, e o que já foi decidido |
| `scripts/author-consultorio.mjs` | como o JSON aprovado é derivado da referência — **é aqui que se muda** |
| `design-system/raevo.tokens.json` | o sistema **como está no código** — desde 21/09 é Consultório. A porta `pnpm raevo:tokens` falha se o código divergir dele |
| `design-system/reference.html` | referência viva, gerada dos tokens (abra no browser) |
| `app/javascript/dashboard/assets/scss/_raevo-tokens.scss` | fonte da verdade em CSS: cor, sombra, raio semântico |
| `app/javascript/dashboard/assets/scss/_raevo-components.scss` | o que token não alcança — e onde vive o par corrigido de `bg-n-brand` |
| `scripts/check-design-pairs.mjs` | a porta que olha para **pares e geometria**, não para valores. Mede contraste nos dois modos |
| `tailwind.config.js` | raio, borda, sombra e fonte do produto inteiro |
| `app/javascript/dashboard/components-next/raevo/` | primitivos: `RaevoPageHeader`, `RaevoStamp` — use, não recrie |
| `app/javascript/dashboard/constants/raevoPalette.js` | cores que viram DADO (etapa, procedimento) |
| `docs/raevo-design-system.md` | especificação, padrões de tela, checklist de PR |
| `output/raevo-design-2026-v2/index.html` | mockups de H · Sereno — **histórico**. A direção aprovada é Consultório; use `design-system/aprovado/` |

E os espelhos no claude.ai, que **não são fonte** (ver a ordem de precedência acima) mas são o
que se mostra a quem não lê código:

| Artefacto | Papel |
| --- | --- |
| [Raevo · Sistema Aprovado](https://claude.ai/artifact/2ACSDXn19DZKFWUos9pnaA) | o demonstrador: catorze telas na direção aprovada, **mais a secção «O sistema, em números»** — cor, tipografia, raio, caixa e as três densidades do indicador, com os valores |
| [Indicadores no canto](https://claude.ai/artifact/AM7QHMa8pwVaiZ7K5GteSL) | a decisão de 26/09 entre as duas propostas de fila, com as medições e as capturas |

**Mudou token, primitivo ou padrão? Actualize o demonstrador na mesma passagem.** Um espelho
desactualizado é pior do que nenhum: alguém desenha a partir dele e a divergência só aparece na
revisão.

---

# Chatwoot Development Guidelines

## Architecture Overview

Chatwoot is a Ruby on Rails (Ruby `3.4.4`) monolith with a Vue 3 frontend bundled by Vite. It is an omnichannel customer support platform: many inbound channels (web widget, email, Facebook, Instagram, WhatsApp, Telegram, SMS, etc.) funnel into a shared conversation/inbox model that agents work from a dashboard.

**Backend (`app/`)** follows a domain-object layering beyond stock Rails MVC — understand these before adding logic:
- `services/` — most business logic lives here (e.g. channel integrations, message processing). Prefer service objects over fat models/controllers.
- `builders/` — construct complex objects (conversations, messages, contacts) from channel payloads.
- `finders/` — encapsulate complex query/filtering logic used by controllers.
- `listeners/` + `dispatchers/` — event-driven side effects. Actions emit events via `Rails.configuration.dispatcher`; listeners react (webhooks, notifications, automation). Trace a feature's side effects through here, not through inline controller code.
- `jobs/` — Sidekiq background jobs (async work; most listeners enqueue jobs).
- `policies/` — Pundit authorization.
- `drops/` — Liquid template variables (canned responses, campaigns, portal).
- `controllers/` — thin; namespaced heavily: `api/v1/`, `api/v2/`, `public/`, `platform/`, `widget/`, `super_admin/`.

**Frontend (`app/javascript/`)** is several separate Vite apps, one per entrypoint (`app/javascript/entrypoints/`), not a single SPA:
- `dashboard/` — the main agent app (Vue 3, Vuex in `store/` migrating to Pinia in `stores/`, routes in `routes/`, API clients in `api/`).
- `widget/` — the embeddable live-chat widget shown to end users.
- `sdk/` — the JS SDK loaded on customer sites that boots the widget.
- `portal/` — public help center. `survey/` — CSAT survey page. `superadmin_pages/` — super admin UI. `v3/` — next-gen app shell.
- `components-next/` — the current component library; the older `components/` tree is being deprecated.

**Enterprise overlay (`enterprise/`)** mirrors `app/` and extends/overrides OSS code via `prepend_mod_with`/`include_mod_with` rather than editing OSS files. See the Enterprise Edition Notes below — any change to core services, controllers, policies, or public API contracts must be checked against the corresponding `enterprise/` files.

**Async & data:** PostgreSQL is the primary store; Redis backs Sidekiq (background jobs, `config/sidekiq.yml`) and Action Cable (real-time websocket updates to the dashboard/widget). The dev process set (`Procfile.dev`) runs `backend` (Rails), `worker` (Sidekiq), and `vite` together.

## Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `pnpm dev` or `overmind start -f ./Procfile.dev`
- **Seed Local Test Data**: `bundle exec rails db:seed` (quickly populates minimal data for standard feature verification)
- **Seed Search Test Data**: `bundle exec rails search:setup_test_data` (bulk fixture generation for search/performance/manual load scenarios)
- **Seed Account Sample Data (richer test data)**: `Seeders::AccountSeeder` is available as an internal utility and is exposed through Super Admin `Accounts#seed`, but can be used directly in dev workflows too:
  - UI path: Super Admin → Accounts → Seed (enqueues `Internal::SeedAccountJob`).
  - CLI path: `bundle exec rails runner "Internal::SeedAccountJob.perform_now(Account.find(<id>))"` (or call `Seeders::AccountSeeder.new(account: Account.find(<id>)).perform!` directly).
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Run Project**: `overmind start -f Procfile.dev`
- **Ruby Version**: Manage Ruby via `rbenv` and install the version listed in `.ruby-version` (e.g., `rbenv install $(cat .ruby-version)`)
- **rbenv setup**: Before running any `bundle` or `rspec` commands, init rbenv in your shell (`eval "$(rbenv init -)"`) so the correct Ruby/Bundler versions are used
- Always prefer `bundle exec` for Ruby CLI tasks (rspec, rake, rubocop, etc.)

## Code Style

- **Ruby**: Follow RuboCop rules (150 character max line length)
- **Vue/JS**: Use ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: Use PascalCase
- **Events**: Use camelCase
- **I18n**: No bare strings in templates; use i18n
- **Error Handling**: Use custom exceptions (`lib/custom_exceptions/`)
- **Models**: Validate presence/uniqueness, add proper indexes
- **Type Safety**: Use PropTypes in Vue, strong params in Rails
- **Naming**: Use clear, descriptive names with consistent casing
- **Vue API**: Always use Composition API with `<script setup>` at the top

## Styling

- **Tailwind Only**:  
  - Do not write custom CSS  
  - Do not use scoped CSS  
  - Do not use inline styles  
  - Always use Tailwind utility classes  
- **Colors**: Refer to `tailwind.config.js` for color definitions

## General Guidelines

- Prefer the smallest production-ready change that solves the current problem.
- Build for the expected production path first. Do not add speculative guards, fallbacks, retries, or edge-case handling unless the caller can actually hit that case or production has proven it necessary.
- When an impossible or misconfigured state would indicate a setup/deployment bug, let it fail loudly instead of silently skipping behavior.
- For locked/internal configs that must exist in production, prefer direct reads (`find`, `find_by!`, required hash keys) over silent fallbacks.
- Do not add validation or response checks unless the code uses the result or the check changes behavior meaningfully.
- Prefer existing repo dependencies/client libraries over hand-rolled protocol code for auth, signing, parsing, or API plumbing.
- Avoid one-use private helpers unless they hide real complexity or make the main flow meaningfully easier to read.
- Prefer minimal, readable code over elaborate abstractions; clarity beats cleverness
- Break down complex tasks into small, testable units
- Iterate after confirmation
- Avoid writing specs unless explicitly asked
- In specs, avoid custom helper methods for setup/data. Prefer `let` values and direct per-example setup; only add a helper when it removes meaningful repeated complexity.
- Remove dead/unreachable/unused code
- Don’t write multiple versions or backups for the same logic — pick the best approach and implement it
- Prefer `with_modified_env` (from spec helpers) over stubbing `ENV` directly in specs
- Specs in parallel/reloading environments: prefer comparing `error.class.name` over constant class equality when asserting raised errors

## Codex Worktree Workflow

- Use a separate git worktree + branch per task to keep changes isolated.
- Keep Codex-specific local setup under `.codex/` and use `Procfile.worktree` for worktree process orchestration.
- The setup workflow in `.codex/environments/environment.toml` should dynamically generate per-worktree DB/port values (Rails, Vite, Redis DB index) to avoid collisions.
- Start each worktree with its own Overmind socket/title so multiple instances can run at the same time.

## Commit Messages

- Prefer Conventional Commits: `type(scope): subject` (scope optional)
- Example: `feat(auth): add user authentication`
- Don't reference Claude in commit messages

## PR Description Format

- Start with a short, user-facing paragraph describing the product change.
- Add a `Closes` section with relevant issue links (GitHub, Linear, etc.).
- For feature PRs, add `How to test` from a product/UX standpoint.
- For bugfix PRs, use `How to reproduce` when helpful.
- Optionally add a `What changed` section for implementation highlights.
- Do not add a `How this was tested` section listing specs/commands.

## Project-Specific

- **Translations**:
  - Only update `en.yml` and `en.json`
  - Other languages are handled by the community
  - Backend i18n → `en.yml`, Frontend i18n → `en.json`
- **Frontend**:
  - Use `components-next/` for message bubbles (the rest is being deprecated)

## Kanban UI/UX Review

For Kanban, opportunity, and CRM-facing UI work, load these project skills together:
- `ui-ux-pro-max`: define the visual system, density, hierarchy, responsive layout, and interaction polish for a focused CRM workspace.
- `frappe-ui-patterns`: guide pipeline, list/detail, activity, bulk-action, and configuration patterns used by CRM products.
- `accessibility-compliance`: audit semantic controls, keyboard navigation, modal focus, screen-reader feedback, contrast, and responsive behavior.

Campos personalizados da oportunidade nascem em **largura total** (`layout.width: 'full'`) numa conta ou funil novo — nos modelos de `KanbanBoards::CreateFromTemplateService` e no preset de marketing de `KanbanBoardSettings.vue`. Meia largura é escolha de quem configura, e normalizar o preset não a desfaz. A ordem das etapas só se muda em Configurações › Geral; o Pipeline não reordena etapas.

Apply them as a single review workflow. Keep the board header compact, use progressive disclosure for filters and configuration, and separate field administration from opportunity editing. Cards and dialogs must preserve stable dimensions, readable hierarchy, and clear empty/loading/error states. Drag-and-drop must distinguish click from drag, show a drop target, update optimistically, and restore the original position with an actionable error when the request fails. Every important action must also have a keyboard-accessible alternative.

## Kanban Visual Automations

The Kanban automation editor is a commercial workflow product, not a general-purpose automation engine. Keep complex integrations, arbitrary HTTP, code, database access, loops, merge/join, and broad AI orchestration in N8N behind approved webhooks.

- Use Vue Flow only as the canvas engine. Keep domain behavior in Vue composables and Rails services, never in custom node presentation components.
- Every workflow node must be registered in `kanbanWorkflowNodeDefinitions.js` with its type, category, Lucide icon, i18n label, and palette availability. Do not duplicate node catalogues in the builder, palette, or inspector.
- A new node is incomplete until it has: backend type/validator support, server-side authorization and board-scoped reference checks, executor and preview behavior, i18n, node definition, contextual inspector form, and focused backend/frontend tests.
- Persist only node id, type, position, edge data, and domain configuration. Icons, labels, summaries, colors, interaction callbacks, and validation decoration are derived UI state and must never be persisted in `flow_definition`.
- Use the Node-RED information architecture: searchable, collapsible palette categories and labeled branch outputs. Use n8n only as a UX reference for contextual configuration, validation, preview, and execution history; do not copy n8n source code or components.
- The canvas is the dominant surface. Do not add a permanent inspector that reduces the canvas width. Selecting a node or edge opens a contextual floating panel with `Configurar`, `Testar`, and `Historico` as applicable.
- Node cards have stable dimensions, a category icon, concise commercial summary, visible validation state, and accessible handles. Do not place full forms inside canvas cards.
- Router behavior is ordered first-match only. Each branch owns an E/OU group and a unique labeled output; every Router has a `Caso contrario` output. Keep `Distribuir caminhos` separate from the commercial action `Distribuir responsavel`.
- Every mouse/drag action needs a keyboard alternative: add from palette, insert after edge, connect, remove edge, reorder branches, open inspector, and publish. Preserve focus on close/error and announce validation results accessibly.
- Use Composition API with small focused components/composables. Do not expand `KanbanWorkflowBuilder.vue` with new node-specific business logic; extract inspectors and shared canvas operations when a second consumer or complex behavior appears.
- Use Tailwind utility classes and existing semantic color tokens only. Keep visual state understandable without color, maintain visible focus rings, and use Lucide icons rather than custom SVG markup.
- Follow TDD: write and run a failing focused test before new node behavior, then implement the smallest change, run affected suites, lint, and `git diff --check`.

## Financeiro Raevo

- Financeiro é opt-in por conta. Nunca exponha credenciais, token de webhook, payload bruto ou identificadores sensíveis em serializadores, histórico comercial ou store do dashboard.
- `FinancePayment` é a fonte de verdade do estado financeiro. Redirecionamento de navegador, clique em link ou mensagem enviada não confirma pagamento; somente webhook idempotente ou confirmação manual elegível altera o estado.
- Mantenha provedores como adaptadores. Asaas é P0 Brasil; Portugal P0 é controle manual em EUR. ifthenpay, Moloni, recorrência e emissão fiscal automática são P1 e não devem ser simulados como concluídos.
- A matriz mínima é: secretaria padrão consulta/cria cobranças e gere somente cobranças manuais; configuração, credenciais, reprocessamento de webhook e estorno exigem permissão financeira explícita. Funções personalizadas usam `finance_view`, `finance_create`, `finance_manage`, `finance_refund` e `finance_configure`.
- O envio automático de cobrança pertence ao Vue Flow: use o gatilho `finance.payment.created` e o nó `send_message` com `{{finance_payment_link}}`. Preserve `payment_id` durante esperas; nunca recupere silenciosamente um link de outra cobrança. Continue exigindo opt-in, janela de canal, template oficial, horário silencioso e limite de frequência.
- Antes de liberar Financeiro, execute request/service specs, teste criação idempotente, webhook repetido/fora de ordem, cancelamento, recebimento manual, estorno, permissões da secretaria e cópia/envio de link. Para avaliação de jornada/visual, aplique `ui-ux-pro-max`, `frappe-ui-patterns`, `accessibility-compliance`, `agentic-browser-testing` e `visual-testing` juntos.

## Porta de Qualidade Visual Raevo

Para qualquer mudança em Kanban, oportunidade, Agenda, Financeiro, Formulários ou Automação, aplique esta sequência antes de chamar a interface de pronta:

1. `ui-ux-pro-max`: defina hierarquia, densidade, estados e transições. Em superfícies operacionais, prefira densidade alta, progressão clara e microinterações de 150–250 ms; não use movimento puramente decorativo.
2. `frappe-ui-patterns`: valide a jornada lista/quadro → detalhe → ação, edição progressiva e configuração separada do trabalho operacional.
3. `accessibility-compliance`: valide rótulos, foco, teclado, contraste, mensagens de erro próximas ao campo e alternativa a qualquer gesto de arrastar.
4. `agentic-browser-testing`: execute uma jornada real com dados de teste, incluindo criação, alteração, erro e recuperação.
5. `visual-testing`: registre screenshot de desktop 1280px antes/depois e investigue sobreposição, corte de texto, vazio excessivo e regressão visual.

As skills desta porta vivem em `.claude/skills/`, que é ignorado pelo git. O que é
versionado é o `skills-lock.json`. Numa máquina nova — Codex incluído — instale-as antes
de começar, senão os cinco passos acima não têm como ser executados:

```bash
pnpm skills:install            # todas as declaradas no lock
pnpm skills:install visual-testing agentic-browser-testing   # só algumas
```

Requer o `gh` autenticado. Os passos 4 e 5 (`agentic-browser-testing` e `visual-testing`)
precisam da aplicação a correr e de um browser: não são análise de código e não podem ser
dados por cumpridos sem uma jornada real e screenshots antes/depois.

### Levantar a aplicação numa sessão de nuvem — receita provada a 26/09/2026

Durante meses os passos 4 e 5 foram dados como impossíveis fora da máquina do
programador, porque `rbenv install 3.4.4` falha: o proxy de egresso recusa
`cache.ruby-lang.org`. **Só o Ruby estava em falta.** Postgres 16, Redis,
Chromium e o rubygems.org estão todos ao alcance, e o Ruby vem pré-construído do
mesmo sítio de onde o GitHub Actions o tira:

```bash
curl -sSL -o /tmp/ruby.tar.gz \
  https://github.com/ruby/ruby-builder/releases/download/toolcache/ruby-3.4.4-ubuntu-24.04.tar.gz
mkdir -p /opt/hostedtoolcache/Ruby/3.4.4 && tar xzf /tmp/ruby.tar.gz -C /opt/hostedtoolcache/Ruby/3.4.4
export PATH=/opt/hostedtoolcache/Ruby/3.4.4/x64/bin:$PATH

apt-get install -y libpq-dev postgresql-16-pgvector   # o `pg` não compila sem o primeiro;
bundle install                                         # o schema não carrega sem o segundo

su postgres -c "/usr/lib/postgresql/16/bin/initdb -D /tmp/pgdata -U postgres --auth=trust"
su postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D /tmp/pgdata -o '-k /tmp/pgrun -c listen_addresses=127.0.0.1' -l /tmp/pg.log start"
redis-server --daemonize yes

cp .env.example .env   # POSTGRES_HOST=127.0.0.1, REDIS_URL=redis://127.0.0.1:6379
bundle exec rake db:create db:schema:load && bundle exec rails db:seed   # john@acme.inc / Password1!
bin/vite dev &
ruby bin/rails s -p 3000 -b 127.0.0.1 &     # invoque o `ruby` pelo caminho absoluto:
                                            # o `bin/rails` apanha o rbenv 3.3.6 e falha
```

Cinco armadilhas que custaram tempo, para não voltarem a custar:

- **Levante o Rails com `DISABLE_MINI_PROFILER=1`.** Esta é a que custou mais:
  sem ela, `/app/login` demora **57 segundos** (o log culpa o ActiveRecord, e a
  culpa não é dele), e ao fim de meia dúzia de pedidos deixa de responder de
  todo. O `rack-mini-profiler` guarda um ficheiro por pedido em
  `tmp/miniprofiler/` e relê a pasta inteira a cada um. Com a variável ligada, a
  mesma página serve em **0,8s**. Limpe também a pasta se já lá estiverem
  centenas de ficheiros.
- **Para capturas, `bin/vite build` vale mais do que `bin/vite dev`.** Em dev o
  primeiro carregamento transforma milhares de módulos um a um e o Vue pode não
  montar em sete minutos — o `<div id="app">` fica vazio sem um único erro na
  consola, que é o pior modo de falhar. Uma build (≈2min) serve páginas
  instantâneas; volta-se a construir depois de cada alteração.
- **`rspec` passa a correr.** Vale mais do que as capturas: os specs de Ruby
  deixam de ser escritos às cegas.
- **O Chromium do Playwright precisa de `--no-proxy-server`**, senão tenta o
  proxy de egresso para chegar a `127.0.0.1`. E **`waitUntil: 'networkidle'`
  nunca resolve** com o Vite em dev: o websocket do HMR fica aberto. Use
  `'load'` — ou `'commit'` mais uma espera por seletor, que é mais robusto.
- **O ecrã de entrada não declara `type=email`/`type=password`.** Preencha
  `form input` por ordem e clique no botão pelo texto.

**Meça, não só capture.** `boundingBox()` sobre o cabeçalho, a faixa e a
superfície de trabalho transforma «ficou muito grande» num número que se discute.
Foi assim que se soube que a fila de indicadores valia 139px no Pipeline e 151px
na Agenda, que a faixa os punha em 76px e 84px, e que a linha os põe em 28px e
37px — e que o selo de variação, que parecia caro, custa 1px.

O que a porta encontrou à primeira execução, e não teria encontrado sem ela: uma
tela que não preenchia a largura (≈375px vazios em 1280) e uma conversão de 0%
numa etapa terminal, onde avançar não é coisa que exista.

Todo controle só por ícone precisa de rótulo acessível e tooltip. Títulos de etapa, oportunidade, procedimento e campo nunca podem depender de `truncate` para caber: use quebra de palavra, largura estável ou detalhe progressivo. Não introduza efeitos, sombras, gradientes ou animações sem ajudar o usuário a compreender estado, prioridade ou transição.

## Manutenção do Upstream Chatwoot

- Chatwoot continua sendo o núcleo de atendimento: identidade, contas, conversas, canais, permissões base e tempo real. Raevo CRM, Agenda, Financeiro, Formulários e Automação devem permanecer como módulos delimitados, com serviços, policies, rotas e componentes próprios.
- Antes de alterar um fluxo de Chatwoot, procure extensão equivalente em `enterprise/`, listener, evento ou service object. Evite editar contratos centrais quando uma composição local resolve o caso.
- Cada atualização do upstream deve acontecer em uma branch `upgrade/chatwoot-x.y.z`, partindo de uma tag imutável da base Raevo. Compare o diff com `upstream`, resolva conflitos por módulo, rode as suites core e Raevo, faça smoke visual e publique primeiro em canário.
- Nunca substitua uma imagem em produção por uma tag mutável. A versão da imagem e as migrations necessárias devem estar registradas no rollout. Consulte `docs/raevo-chatwoot-upstream-maintenance.md` antes de iniciar um upgrade.

## Ruby Best Practices

- Use compact `module/class` definitions; avoid nested styles

## Enterprise Edition Notes

- Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code.
- When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.
- Follow the Enterprise development practices documented here:
  - https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

Practical checklist for any change impacting core logic or public APIs
- Search for related files in both trees before editing (e.g., `rg -n "FooService|ControllerName|ModelName" app enterprise`).
- If adding new endpoints, services, or models, consider whether Enterprise needs:
  - An override (e.g., `enterprise/app/...`), or
  - An extension point (e.g., `prepend_mod_with`, hooks, configuration) to avoid hard forks.
- Avoid hardcoding instance- or plan-specific behavior in OSS; prefer configuration, feature flags, or extension points consumed by Enterprise.
- Keep request/response contracts stable across OSS and Enterprise; update both sets of routes/controllers when introducing new APIs.
- When renaming/moving shared code, mirror the change in `enterprise/` to prevent drift.
- Tests: Add Enterprise-specific specs under `spec/enterprise`, mirroring OSS spec layout where applicable.
- When modifying existing OSS features for Enterprise-only behavior, add an Enterprise module (via `prepend_mod_with`/`include_mod_with`) instead of editing OSS files directly—especially for policies, controllers, and services. For Enterprise-exclusive features, place code directly under `enterprise/`.

## Branding / White-labeling note

- For user-facing strings that currently contain "Chatwoot" but should adapt to branded/self-hosted installs, prefer applying `replaceInstallationName` from `shared/composables/useBranding` in the UI layer (for example tooltip and suggestion labels) instead of adding hardcoded brand-specific copy.
