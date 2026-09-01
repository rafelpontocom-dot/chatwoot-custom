# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
(Note: `CLAUDE.md` is a symlink to `AGENTS.md` — edit this file to update both.)

# Raevo Design System — LEIA ANTES DE MEXER EM QUALQUER UI

Este fork é o **Raevo**. Toda interface — tela nova, componente novo, ajuste em tela
existente — segue a direção **H · Sereno**, aprovada em 29/08/2026.

**Especificação completa e obrigatória: [`docs/raevo-design-system.md`](docs/raevo-design-system.md).**
Leia antes de escrever CSS ou markup. As regras abaixo são o resumo executável.

## As sete regras

1. **Nunca escreva cor, raio, sombra ou fonte literal.** Nada de `bg-[#2563EB]`,
   `style="color:#111"`, `border-radius: 8px`. Use as classes `n-*` do Tailwind e os
   tokens `--raevo-*`. Se falta um token, crie em
   `app/javascript/dashboard/assets/scss/_raevo-tokens.scss` — nunca no componente.

2. **Nunca edite `_next-colors.scss`, e não mude cor em `theme/colors.js`.** São arquivos
   upstream; editá-los gera conflito em todo `git pull` do Chatwoot. A identidade vive em
   `_raevo-tokens.scss`, que é importado depois e vence na cascata.

3. **`shadow-sm` é `none` de propósito.** Em repouso o espaço separa, não a sombra. Sombra
   só para o que realmente flutua: modal, menu, drawer (`shadow-lg`).

4. **Botão e campo de uma linha são pílula** (`rounded-full`, já é o padrão global).
   Card e painel usam `rounded-xl` (13px). Textarea usa `rounded-lg`.

5. **Estado nunca se comunica só por cor.** Sempre cor + ícone + texto. É requisito de
   acessibilidade (WCAG 2.2), não preferência estética.

6. **Tipografia só na escala.** Seis degraus: `text-micro` (11px, piso, só caixa alta e
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

Exemplos prontos: `KanbanAutomations.spec.js`, `KanbanBoardSettings.spec.js`.

## Antes de abrir PR

```bash
pnpm raevo:design    # falha se algum componente do Raevo escrever cor literal
pnpm raevo:palette   # revalida a paleta de etapas
```

## Onde a identidade mora

| Arquivo | Papel |
| --- | --- |
| `app/javascript/dashboard/assets/scss/_raevo-tokens.scss` | fonte da verdade: cor, sombra, raio semântico |
| `app/javascript/dashboard/assets/scss/_raevo-components.scss` | o que token não alcança |
| `tailwind.config.js` | raio, borda, sombra e fonte do produto inteiro |
| `app/javascript/dashboard/components-next/raevo/` | primitivos: `RaevoPageHeader`, `RaevoStamp` — use, não recrie |
| `app/javascript/dashboard/constants/raevoPalette.js` | cores que viram DADO (etapa, procedimento) |
| `docs/raevo-design-system.md` | especificação, padrões de tela, checklist de PR |
| `output/raevo-design-2026-v2/index.html` | mockups aprovados (direção "H · Sereno") |

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
