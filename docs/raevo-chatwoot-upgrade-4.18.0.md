# Upgrade Chatwoot 4.18.0: inventario Raevo

Este documento acompanha `docs/raevo-chatwoot-upstream-maintenance.md`. A base real do fork e o commit upstream `8818d276b954ac4f84cffd8915c99f40e43804ed` (2026-07-02), nao a string `4.15.1` que ainda aparecia no `package.json`. O ponto Raevo anterior ao upgrade e `b771ec3522e2f95b05f6d1e184e35ee42f303cc4`, protegido pela tag `raevo/pre-upgrade-4.18.0-20261002`. O alvo upstream e a tag imutavel `v4.18.0` (`5c1487713ff2ea407188855211533a1e30e24589`).

## Metodo

1. Atualizar remotos e tags, conferir `git merge-base` e criar uma tag de retorno.
2. Fazer o merge da tag upstream em `upgrade/chatwoot-4.18.0`, numa worktree separada. A branch publicada permanece inalterada durante a revisao.
3. Comparar os caminhos modificados desde a base em ambos os lados. Neste ciclo, 117 caminhos se sobrepoem e 59 tiveram conflitos textuais. Ausencia de conflito textual nao significa ausencia de regressao.
4. Mesclar traducoes JSON por chave, preservar as chaves Raevo e incorporar novas chaves upstream. Revisar colisao semantica e placeholders.
5. Gerar `pnpm-lock.yaml` a partir de `package.json` resolvido, sem escolher um lockfile antigo inteiro. Conciliar `db/schema.rb` com as migrations de ambos os lados.
6. Validar lint, build, specs Raevo e upstream nas areas tocadas. Publicar branch para CI e revisao. So promover a imagem depois de smoke em staging e conta canario.

Nao mover arquivos nativos para uma pasta de copias a ser reaplicada: isso esconderia contratos e deixaria a cada upgrade um segundo sistema divergente. Modulos proprios ficam em namespaces, rotas, migrations e componentes Raevo. O pouco que precisa alterar o nucleo fica rastreado abaixo, com testes.

## Contratos criticos

| Area | Extensao Raevo | Contrato upstream a preservar | Verificacao |
| --- | --- | --- | --- |
| Super Admin | provisionamento, mapeamento, handoff e rotacao Raevo AI; grupos Google Agenda e Marketing | suspensao de conta, configuracao Shopify e segredo Slack | `spec/controllers/super_admin/accounts_controller_spec.rb`, `app_config_controller_spec.rb` |
| Inbox WhatsApp | nome do atendente, saudacao de atribuicao, marcar como lida | destinatario BSUID, upload de midia por ID, reconexao e saude do canal | specs de provider e `ConfigurationPage.spec.js` |
| Atendimento | atalho de busca, conversa dentro do CRM, dados da oportunidade | contagens, macro e novos filtros | `ChatListHeader.spec.js`, `commandbar.spec.js`, specs do sidebar |
| CRM | Kanban, Agenda, Financeiro, Formularios, Automacao e IA em namespaces proprios | modelos, eventos, jobs e associacoes upstream | specs Raevo por modulo e smoke E2E |
| Importacao | `kanban_cards` e seu job | CSV de contatos e importacoes Freshdesk/Intercom | `spec/models/data_import_spec.rb` |
| Marca | logo, tema e login Raevo | autenticacao, MFA e limite de sessoes | spec de login e verificacao visual |

## Portas para promover

- [x] `git diff --check`, nenhum marcador de conflito e `bundle check`.
- [x] `pnpm install --frozen-lockfile`, lint, testes de frontend e `bin/vite build --mode=test` (build anterior passou; repeticao final reutilizou o cache sem mudancas observadas).
- [x] RSpec direcionado de Super Admin, WhatsApp, importacao, CRM e formularios: 1.682 exemplos, 0 falhas.
- [ ] Teste Rails com banco limpo: `RAILS_ENV=test bundle exec rails db:test:prepare` e suites direcionadas; a rodada atual usou o banco local existente.
- [ ] Em staging, `bundle exec rails db:migrate` no servico API, nunca somente no admin; confirmar `db:migrate:status`.
- [ ] Smoke da conta canario: login PT-BR/PT-PT, Super Admin Raevo AI, inbox com nome do atendente, conversa, Pipeline, Agenda, Financeiro e Formulários.
- [ ] Confirmar background jobs, eventos, callbacks e nenhuma falha 500 em logs apos a imagem.
- [ ] Guardar o digest da imagem atual para rollback. Nao reverter migrations de dados sem plano proprio.

Frontend direcionado: 53 arquivos e 890 testes foram executados. Quatro testes do painel Raevo AI dependiam das traducoes completas removidas do setup global pelo upstream; apos usar `withFullI18n`, os quatro passaram. `pnpm install --frozen-lockfile --ignore-scripts`, ESLint dos arquivos ajustados, Prettier, placeholders i18n e checks de design Raevo passaram. Histoire ainda declara peer de Vite ate v5, enquanto este upgrade usa Vite 6; acompanhar em CI.

Nenhuma migration de producao foi executada nesta branch. O merge tambem nao publica imagem nem altera a stack Swarm.

O merge em branch de upgrade nao equivale a deploy. A tag anterior permite retornar ao codigo anterior; o banco exige compatibilidade e backup antes da migracao.
