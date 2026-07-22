# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
(Note: `CLAUDE.md` is a symlink to `AGENTS.md` — edit this file to update both.)

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
