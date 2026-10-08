# Retomar o Raevo CRM noutra sessão (nuvem)

Escrito para a sessão que vai continuar este trabalho a partir do repositório, sem ter
acompanhado a conversa. Data: 07/10/2026.

## Onde ligar

| | |
| --- | --- |
| Repositório | `rafelpontocom-dot/chatwoot-custom` (fork do Chatwoot) |
| **Branch** | **`fix/pos-merge-4.18-e-backlog-thiago`** |
| Remoto local | chama-se `fork` |
| Branch a NÃO usar | `deploy/custom-whatsapp-kanban` — parado no merge do 4.18 (`8f01cb72d`). Gerar imagem dele é regressão |

Último commit em 07/10: `7cbb6b64e`. «Custom checks (WhatsApp + Kanban)» verde.
O workflow «Run Chatwoot CE spec» está vermelho no job `security-scan` por duas CVEs
High do `ruby_llm 1.15.0` (dependência do upstream, cartão `123jpnbcdax`) — **não** é
regressão do nosso código.

## Ambiente

- Ruby 3.4.4 por rbenv: `eval "$(rbenv init -)"` antes de qualquer `bundle exec`.
- Node/pnpm para o frontend. `pnpm exec vitest run --no-coverage <padrão>`.
- Portas obrigatórias antes de qualquer commit:
  `pnpm raevo:design`, `pnpm raevo:tokens`, `pnpm raevo:palette`,
  `node scripts/check_frontend_i18n_placeholders.mjs`, `pnpm exec eslint`,
  `bundle exec rubocop`.
- Design system vigente: **A · Consultório**. Marca `#171717`, controlo 32px/raio 10px,
  cartão raio 14px, paleta de etapas `#2563EB #0F9D8F #B45309 #A21CAF #98A0AE`.

## O que entrou em 07/10 (seis commits)

| Commit | O que |
| --- | --- |
| `422545519` | A oportunidade ganha coluna lateral; Contacto é a primeira secção |
| `b0142a96e` | Agenda, Financeiro, Formulários e Histórico saem das abas para a coluna; na conversa, link para o cartão em vez da ficha inteira |
| `3f0fbb8a4` | A pessoa reordena as secções da coluna; a ordem fica em `ui_settings` |
| `c1efc0b77` | Criar oportunidade numa etapa que exige campos deixa de ser impossível (funil e conversa) |
| `4aedabf7d` | Etiqueta com visibilidade: de todos / de um time / só minha |
| `7cbb6b64e` | A etiqueta pessoal de outro agente deixa de viajar no payload do cartão |

Cartões em **validação** no ClickUp (lista `901513885218`, workspace `31122432`):
`123jpnbcb57`, `123jpnbcb53`, `123jpnbcb5p`.

## A primeira coisa a fazer, e a mais importante

**Nada do que entrou em 07/10 foi aberto num browser.** Os testes provam que as peças
existem, abrem e trazem os dados certos; não provam que a tela está como foi aprovado.

O `AGENTS.md` deste repositório define uma porta visual de cinco passos
(`ui-ux-pro-max`, `frappe-ui-patterns`, `accessibility-compliance`,
`agentic-browser-testing`, `visual-testing`) e as skills estão em `.claude/skills`.
Correr essa porta sobre estas quatro telas é o trabalho que falta:

1. **Oportunidade** (funil › clicar num cartão): a coluna da direita com as cinco
   secções, abrir/fechar, subir/descer, e a mesma coluna no telemóvel. Desenho aprovado:
   `docs/raevo-aprovacao.md`, secção «A oportunidade troca as abas pela coluna lateral».
2. **Criar oportunidade numa etapa que exige campo**: o campo tem de aparecer dentro do
   formulário, aceitar valor e criar. Pelo funil e pelo painel da conversa.
3. **Painel da conversa**: a oportunidade ligada mostra resumo e atalho para o funil, e
   **não** abre a ficha inteira sozinha.
4. **Configurações › Etiquetas**: o seletor «Quem vê esta etiqueta» com os três níveis; e
   um agente (não administrador) a criar a etiqueta dele pelo atalho da conversa.

Capturas a 1280px e a 390px, antes e depois.

## Dívida conhecida, por ordem de importância

1. **Fuga de título de etiqueta no funil.**
   `app/views/api/v1/accounts/kanban_boards/_card.json.jbuilder` serializa
   `card.contact.label_list` — títulos de etiquetas do **contato**, do acts_as_taggable,
   sem passar por catálogo nenhum. Uma etiqueta pessoal de outra pessoa ainda aparece
   ali. É o buraco que torna a palavra «visibilidade» incompleta.
2. **Mover com erro cru.** Trocar a etapa pelo select do painel da conversa ou pela ficha
   da oportunidade mostra «procedimento is required» em vez de oferecer o campo. Não é
   beco (os campos estão à vista nessas telas), mas também não é preenchimento
   facilitado. O funil já faz o certo — copiar de `KanbanView.vue`
   (`pendingAssistedMove`).
3. **Etiqueta pessoal órfã.** Autor que sai da conta deixa a etiqueta invisível para
   todos; continua a existir e mantém as marcações. Mexer nela exige console. É o mesmo
   buraco que as macros pessoais já têm no Chatwoot.
4. **CVEs do `ruby_llm`** (cartão `123jpnbcdax`): `>= 2.0.0.rc1` é pré-lançamento numa
   major. Decisão pendente do Pedro.
5. **Tela branca do Marketing** para quem USA o módulo (metade do `123jpnbcb5f`). A
   entrada do menu já está escondida para contas sem o módulo; a tela em si não foi
   reproduzida.
6. **18 testes de data/hora vermelhos**, anteriores a este trabalho e confirmados em
   árvore limpa: `timeHelper`, `snoozeHelpers`, `useExactTimestamp`, `ReportsDataHelper`,
   `availabilityHelpers`. São specs dependentes da data do sistema.

## Cartões em «iniciar», por prioridade

`123jpnbcb4w` (alta — mencionar participantes de grupo de WhatsApp),
`123jpnbcb56`, `123jpnbcb50` (seleção múltipla de caixa de entrada — o Pedro manteve o
pedido depois de eu avisar que duplica histórico), `123jpnbcb4z`,
`123jpnbcb5n`, `123jpnbcb5k`, `123jpnbcb5j`, `123jpnbcb5h`, `123jpnbcb5d`,
`123jpnbcb5m`, `123jpnbcb5a`, `123jpnbcb5q`, `123jpnbcb55`.
Em «desenvolvimento»: `123jpnbc242` (notificação de mensagens novas).

## Regras de trabalho deste projeto

- **Registar tudo em `../AUDITORIA-CODEX.md`** (fora deste repositório): o que mudou,
  onde, porquê, o que foi verificado e **o que NÃO foi**. O Pedro manda tudo ao Codex
  para auditoria.
- **ClickUp:** mover o cartão para o estado certo, **pôr a data no dia em que se
  trabalhou**, e **lançar tempo** — reconstruído dos horários dos commits, dizendo que é
  reconstruído. Nunca inventado.
- Distinguir sempre: implementado / verificado localmente / verificado em integração /
  planeado. Nome de ficheiro, teste verde ou nome de commit não contam como verificação.
- Nunca copiar credenciais, `.env` ou dados de pacientes para documentos ou capturas.

## Quatro ciladas que já me apanharam aqui

1. **`git add -A` nesta árvore varre trabalho de outra pessoa** para o teu commit.
   Adicionar sempre ficheiro a ficheiro.
2. **`rails db:migrate` corre o `annotate`** e mexe em ~13 modelos sem relação com a tua
   migração. Reverter esses com `git checkout --` antes de commitar.
3. **`db/schema.rb` redespejado traz ruído** (reordenação de índices, `Schema[7.2]` em vez
   de `[7.1]`). Preferível editar à mão só a tabela afetada e a linha da versão.
4. **O duplo de teste que concorda contigo não é prova.** Já aconteceu três vezes neste
   repositório: teste verde com a produção partida porque o duplo devolvia `undefined`
   onde a produção devolve `{}`, porque o spec configurava o caminho que o produto não
   usa, ou porque o elemento nem renderizava. Antes de confiar num teste novo, confirmar
   que ele falha quando devia falhar.
