# Manutenção do Upstream Chatwoot

## Decisão arquitetural

Raevo CRM mantém o Chatwoot como núcleo de atendimento. Conversas, canais, autenticação, contas, inboxes, notificações e tempo real continuam no produto upstream. Os módulos Raevo devem ser extensões de domínio: Kanban, Agenda, Financeiro, Formulários e Automação usam seus próprios serviços, policies, eventos, APIs e telas.

Essa divisão preserva o valor das atualizações de segurança e canais do Chatwoot sem obrigar o produto a reimplementar atendimento omnichannel.

## Regras de isolamento

- Preferir `app/services`, listeners, eventos e APIs Raevo antes de alterar um fluxo central do Chatwoot.
- Verificar sempre `enterprise/` quando um controller, policy, modelo ou contrato compartilhado for alterado.
- Persistir dados Raevo em tabelas próprias e não em colunas genéricas de conversa sem justificativa de compatibilidade.
- Não acoplar interface Raevo a seletores internos frágeis do dashboard quando uma API ou composable existe.
- Cobrir todo contrato público novo com request spec e toda regra comercial com service spec.

## Onde mexer: os três anéis

Uma atualização do Chatwoot não apaga dados nem o que vive em ficheiros nossos. O que ela pode levar
sem conflito é uma mudança **dentro de um ficheiro do Chatwoot**. Por isso, antes de alterar
comportamento nativo, escolha o anel mais de fora que resolve:

| Anel | O que é | Custo num upgrade |
| --- | --- | --- |
| **1. Nosso** | ficheiro que o Chatwoot não tem: módulos Kanban/Agenda/Financeiro, `components-next/raevo/`, serviços, listeners, os JSON de tradução próprios (`kanban.json`, `finance.json`…) | nenhum |
| **2. Costura** | o ficheiro nativo ganha **um ponto de entrada** de 1–3 linhas — um `<RaevoAlgo />`, um `import`, um `Classe.prepend(Raevo::…)` — e toda a lógica fica no anel 1 | reaplicar 1–3 linhas, que o contrato aponta |
| **3. Edição** | lógica nossa no meio do ficheiro nativo | resolver à mão, e o upstream pode reescrever sem conflito |

Por camada:

- **Servidor.** Onde a classe chama `prepend_mod_with`, o Chatwoot já procura extensões — inclusive
  um namespace `Custom::` (`ChatwootApp.extensions`), mas a pasta `custom/` não é carregada por
  `config/application.rb` e várias classes (`Label`, `LabelPolicy`, `Labels::*Service`) nem chamam
  o gancho. O caminho de anel 2 é um initializer nosso com `Rails.application.config.to_prepare` que
  faz `Classe.prepend(Raevo::ClasseExtension)` — zero linhas no ficheiro nativo. Rotas novas vão num
  ficheiro nosso com `draw(:raevo)`: uma linha em `config/routes.rb`.
- **Tela.** O componente nativo recebe só o ponto de entrada (`<RaevoConversationExtras />`, um slot,
  um composable) e a lógica vive em `components-next/raevo/` ou no módulo. Substituir o ficheiro
  inteiro por alias do Vite é o último recurso: congela a tela e perde as correções do upstream.
- **Tradução.** Chave nova vai num JSON nosso. Editar `conversation.json` ou `settings.json` do
  upstream é conflito garantido: o Crowdin reescreve-os em cada versão.
- **Estilo.** Só tokens (`_raevo-tokens.scss`); markup nativo intocado.

Anel 3 continua permitido quando não há costura possível — mas nasce com contrato e teste de
comportamento, e é candidato a descer para o anel 2.

## A porta do inventário

`node scripts/raevo-upstream-audit.mjs --check-native-coverage` corre no CI (`custom_checks.yml`,
job `lint-frontend`). Compara a árvore com a tag oficial em `upstreamBase`
(`config/raevo/upstream-contracts.json`) e exige que **cada ficheiro nativo alterado ou apagado**
esteja numa de três listas:

1. **um contrato** em `upstream-contracts.json`, com teste que falha se a mudança se perder;
2. **`regenerated`** — `Gemfile.lock`, `pnpm-lock.yaml`, `db/schema.rb`, que se regeneram com a
   ferramenta e não se resolvem à mão;
3. **a dívida** em `config/raevo/upstream-debt.json` — os ficheiros que já estavam alterados sem
   contrato quando a porta nasceu (188 a 09/10/2026; 171 depois da primeira ronda da camada 2).

A dívida **só encolhe**. Num PR, a porta compara-a com a do ramo base e recusa entradas novas;
recusa também entradas que já têm contrato ou que deixaram de diferir do upstream. Ficheiro nativo
novo, portanto, só entra com contrato.

**No upgrade:** muda-se `upstreamBase` para a tag nova no mesmo PR do merge. A porta passa a medir
contra ela; o que o upstream tiver absorvido sai da dívida.

## Ciclo de atualização

1. Adicionar ou atualizar o remoto `upstream` para `chatwoot/chatwoot`.
2. Criar uma tag imutável da base atualmente publicada, por exemplo `raevo-base-4.17.0`.
3. Criar `upgrade/chatwoot-x.y.z` a partir dessa tag e trazer a versão upstream desejada.
4. Usar `git range-diff` e `git diff` para listar arquivos alterados pelo upstream que também foram modificados pelo Raevo.
5. Resolver conflitos respeitando primeiro extensões e módulos Raevo; evitar apagar comportamento upstream novo sem uma decisão registrada.
6. Rodar lint, testes de contratos Raevo, testes de canais relevantes e smoke visual de Login, Atendimento, Kanban, Agenda, Financeiro e Automação.
7. Construir imagem com tag imutável, aplicar migrations em staging, testar uma conta canário e só então atualizar o Swarm completo.

## O que o merge do 4.18 deixou passar, e a porta que o apanha

A atualização para o 4.18.0 (03/10/2026) passou em lint, testes e CI e chegou à imagem com dois defeitos de tela:

- **A barra lateral rebentava ao navegar.** `SidebarGroupHeader.vue` entrou em conflito. A resolução ficou com o `router-link` do Raevo e o `href` do upstream, sem o `to` de nenhum dos dois. O `RouterLink` real lança erro sem `to`; nos testes ele é stubado e aceita calado. Sintomas: Pipeline sumia e o painel esquerdo desaparecia ao clicar em Início, Agenda, Marketing ou Formulários.
- **A tela de Contatos lançava erro.** O Raevo tinha trocado chaves de i18n dinâmicas por um mapa fixo em `ContactsForm.vue`. O upstream acrescentou o perfil WhatsApp à lista; o mapa não o tinha. Aqui nem houve conflito: o git juntou as duas metades sem avisar.

Nenhum dos dois é apanhável por lint ou por teste com filhos stubados. Só aparecem com a aplicação a correr. Por isso o passo 6 do ciclo não pode ser dado por cumprido sem estes três:

1. **Listar os ficheiros resolvidos à mão.** São os de maior risco, e a lista sai de um comando:

   ```bash
   git merge-tree --write-tree --name-only --no-messages <base-raevo> <tag-upstream> | tail -n +2
   ```

   No 4.18 foram 27 fora dos ficheiros de tradução. Cada um é relido contra os dois lados (`git merge-file -p --diff3`), à procura de resolução que ficou com metade de cada.

2. **Listar os ficheiros que os dois lados alteraram sem conflito.** Um mapa fixo, uma lista de opções ou uma assinatura de função mudados pelo upstream partem código Raevo que o git considera intacto.
3. **Varrer as telas no browser, por clique.** Entrar, clicar em cada item da barra lateral por ordem, abrir um funil, uma oportunidade, uma conversa e um contato, com a consola aberta. Erro de consola ou item que desaparece reprova o upgrade. Carregar a URL diretamente não chega: os dois defeitos só apareciam ao navegar.

Componente do upstream que o Raevo altera ganha um teste com o router verdadeiro, não com `RouterLink` stubado (`sidebar/specs/SidebarGroupHeader.spec.js` é o modelo).

### Validação executável depois do incidente

- O teste do cabeçalho foi executado com a resolução quebrada (`router-link` com `href`, sem `to`) e falhou ao clicar. Com a correção, passa. Não basta registrar um teste que só foi visto verde.
- `ContactsForm.spec.js` monta os perfis sociais em PT-BR e PT-PT, verifica todos os textos de exemplo e edita o perfil WhatsApp. Remover o seu texto de exemplo reproduz a exceção de `placeholder.length`.
- O check `frontend-tests` inclui os módulos Raevo e também barra lateral, formulário de contato, imagem do canal, foco da navegação e título da guia. Esses contratos compartilhados não podem ficar fora do CI por não terem `kanban` no caminho.
- O check `backend-tests` termina com o smoke Playwright de navegação. Usa Rails real, banco de teste e dados próprios, entra pela tela de login e navega por clique. Confere Pipeline, abertura do contato e carregamento da imagem da caixa. Erros da aplicação e respostas de API com falha reprovam o teste. As capturas e traces ficam no artefato `raevo-navigation-smoke` do GitHub Actions.
- A publicação da imagem exige os quatro jobs da rodada mais recente de `custom_checks.yml` aprovados no mesmo SHA. Checks do upstream com nomes iguais não substituem os checks Raevo. O workflow manual falha antes do build se algum ainda estiver em execução, estiver ausente ou tiver falhado.

Para repetir localmente, use um banco de teste isolado, sem reaproveitar os dados de produção:

```sh
export RAILS_ENV=test
export POSTGRES_DATABASE=raevo_navigation_smoke_test
export REDIS_URL=redis://127.0.0.1:6379/15
export FRONTEND_URL=http://127.0.0.1:3011
bundle exec rails db:create db:schema:load db:migrate
bundle exec rails runner script/raevo/navigation_smoke_seed.rb
pnpm exec playwright install chromium
pnpm exec playwright test --config tests/playwright/playwright.navigation.config.ts
```

`db:schema:load` apaga as tabelas desse banco: use somente o banco isolado acima. A jornada precisa dos assets de teste compilados (`bundle exec vite build --mode=test`) ou do Vite em modo test, de PostgreSQL/Redis e de libvips, como a imagem Docker. O seed recusa execução fora de `RAILS_ENV=test` e deve rodar uma vez por banco novo. O Playwright levanta e encerra o servidor na porta 3011. A contagem no título continua dependente de `conversation_unread_counts`; esta correção não altera a escolha da conta em produção. Só a conta sintética tem a flag habilitada, com uma mensagem não lida para validar o título. Ao sair do dashboard, o título original é restaurado, evitando contadores acumulados ao entrar novamente.

## Checklist de release

- [ ] ficheiros resolvidos à mão relidos contra os dois lados;
- [ ] varrimento por clique sem erro de consola;
- [ ] smoke de navegação aprovado no CI, com capturas revisadas;

- [ ] versão upstream e SHA Raevo registrados na imagem;
- [ ] migrations listadas e aplicadas somente pelo container `chatwoot_api`;
- [ ] `db:migrate:status` sem pendências;
- [ ] testes customizados e lint concluídos;
- [ ] fluxos canário: conversa, oportunidade, agendamento, cobrança e automação;
- [ ] rollback definido para a imagem anterior e nenhuma migration destrutiva sem plano reversível.

## Passo a passo obrigatório

Não existe garantia de zero regressões em um fork. A estrutura abaixo torna as mudanças rastreáveis e bloqueia a imagem quando faltam verificações automatizadas. A aceitação no ambiente publicado continua necessária.

### 1. Preservar a versão atual

- Registrar branch, SHA, tag e digest da imagem nos três serviços do Swarm. Registrar também as migrations aplicadas e as variáveis necessárias, sem copiar segredos para o Git.
- Fazer backup restaurável do PostgreSQL e dos anexos antes de migrations. Confirmar como restaurar, não somente que o arquivo existe.
- Trabalhar em branch e worktree próprios, sem alterar alterações locais de outra pessoa. Criar uma tag imutável de pré-upgrade e outra da base upstream comprovada pelo histórico.
- Buscar a tag exata da versão desejada e o histórico completo. Não identificar a base por `package.json`, pela data de um arquivo ou pela presença de uma funcionalidade.

### 2. Gerar o inventário antes do merge

No worktree de upgrade, executar:

```sh
node scripts/raevo-upstream-audit.mjs --check-contracts
node --test scripts/tests/raevo-upstream-audit.test.mjs
node scripts/raevo-upstream-audit.mjs \
  --raevo <tag-raevo-pre-upgrade> \
  --upstream <tag-upstream> > /tmp/raevo-upstream-audit.json
```

O relatório registra os SHAs, a base comum real, todos os arquivos alterados pelos dois lados, os testes associados e colisões de versões de migration. Recusa clones rasos e referências inexistentes. A lista inclui mudanças que o Git juntaria automaticamente, não apenas conflitos. `unregisteredOverlaps` exige revisão manual e atualização do catálogo `config/raevo/upstream-contracts.json`; não significa que esses arquivos sejam seguros.

O catálogo associa caminhos nativos modificados a contratos e testes existentes. Ele não prova cobertura semântica nem substitui a revisão. Novos contratos compartilhados entram no catálogo e no CI junto com a implementação.

### 3. Resolver e revisar

- Relacionar todos os conflitos e todos os overlaps automáticos do relatório. Para cada um, registrar: comportamento upstream, comportamento Raevo preservado, decisão e teste.
- Comparar assinaturas de funções, props, rotas, opções de campos, policies, eventos e listas de tradução. Verificar também extensões em `enterprise/`.
- Não manter uma pasta espelho de arquivos nativos antigos para copiá-los depois do upgrade: isso apagaria correções e recursos novos. Extensões de domínio ficam em módulos próprios; adaptações do núcleo ficam no histórico Git e no catálogo de contratos.
- Resolver traduções por chave, sem substituir um JSON inteiro por uma das versões. Conferir PT-BR/PT-PT e as chaves dos módulos Raevo.
- Revisar dependências e regenerar locks com o gerenciador correto. Conferir migrations próprias e upstream, incluindo timestamps repetidos, schema e compatibilidade de rollback. Não apagar migrations já aplicadas.

Contratos mínimos a preservar:

| Área                | Regressão/aceite obrigatório                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Navegação           | Pipeline e todos os módulos por clique, barra lateral presente, router real                                                                     |
| Contatos            | Todos os perfis sociais novos, tradução real, edição e salvamento                                                                               |
| Identidade da caixa | Imagem em canais, Minhas/Não atribuídas/Todos, layouts compacto/expandido, histórico, notificações e busca; fallback quando ausente ou inválida |
| Etiquetas           | Ordem manual salva, isolamento entre contas e autorização; ordenação da barra lateral respeitada                                                |
| Início              | Conteúdo alcançável por rolagem, inclusive janela baixa                                                                                         |
| Superadmin          | Liberação de módulos e configurações de conta/instalação mantidas                                                                               |
| WhatsApp            | Nome do atendente, saudação e opções da caixa preservadas                                                                                       |
| Marca/idioma        | Logo, favicon, login, nome da instalação e PT-BR/PT-PT preservados                                                                              |
| Notificações        | Som e contagem da guia respeitam preferências/flags, sem habilitar flags de produção implicitamente                                             |
| CRM                 | Oportunidade, calendário, financeiro, formulários e automação mantêm dados, permissões e vínculos                                               |

### Adaptações em telas nativas — o que reaplicar a cada upgrade

O catálogo diz **que** um ficheiro nativo foi tocado; esta tabela diz **o quê**, para quem resolve o
conflito saber o que tem de sobreviver. Cada linha tem um contrato no catálogo e um teste que falha
se a adaptação se perder. Cada alteração no ficheiro nativo leva um comentário `RAEVO (data, cartão)`.

| Ficheiro nativo | O que o Raevo mudou | Contrato · teste |
| --- | --- | --- |
| `conversation/ContactPanel.vue` | a secção «Oportunidades» usa `KanbanConversationCards` (só criar + linha que leva ao funil) | `conversation-sidebar-native` · `ContactPanel.spec.js` |
| `conversation/labels/LabelBox.vue` | o atalho de etiquetas oferece **criar** a qualquer pessoa, não só ao administrador (a do agente nasce pessoal, no servidor) | `conversation-sidebar-native` · `LabelBox.spec.js` |
| `conversation/Macros/List.vue` | com macros já criadas, um link «Adicionar uma nova macro» no fim da lista, para `settings/macros/new` (08/10, cartão 123jpnbcb55) | `conversation-sidebar-native` · `Macros/specs/List.spec.js` |
| `WootWriter/Editor.vue`, `conversation/ReplyBox.vue`, `config/routes.rb` | na **resposta** de um grupo de WhatsApp (contato `…@g.us`), o `@` abre `WhatsappGroupMentions` (quem já escreveu no grupo + `@all`) em vez das ferramentas, e insere o texto que o WAHA transforma em menção (`@<dígitos>@lid`, `@<dígitos>`, `@all`). Nota interna e conversas com pessoa ficam como estavam. Rota `whatsapp_group_participants` (08/10, cartão 123jpnbcb4w) | `conversation-reply-group-mentions` · `EditorWhatsappGroupMentions.spec.js`, `ReplyBox.spec.js`, `whatsapp_group_participants_controller_spec.rb` |
| `conversation/customAttributes/CustomAttributes.vue` | «Atributos do contato» no painel da conversa passa por `withoutWhatsappAddressing` — sem `waha_whatsapp_*` (JID, LID, Chat ID), como a ficha do contato e a da oportunidade (08/10, cartão 123jpnbcb5e) | `conversation-contact-attributes` · `customAttributes/specs/CustomAttributes.spec.js` |
| `sidebar/Sidebar.vue`, `sidebar/SidebarGroupHeader.vue`, `sidebar/SidebarGroup.vue` | número de conversas por ler: ao lado de «Conversas» com o grupo fechado (`getterKeys.count`; o cabeçalho passa a mostrá-lo também em grupo fechado) e no ícone da barra estreita (`SidebarUnreadBadge`); `useUnreadFavicon` desenha-o no ícone da guia. As flags `conversation_unread_counts` e `unread_count_for_filters` foram ligadas em todas as contas pela migração `20261008190000` — **conta nova liga-se no Super Admin** (08/10, cartão 123jpnbc242) | `sidebar-unread-counts` · `SidebarGroupHeader.spec.js`, `useUnreadFavicon.spec.js` |
| `NewConversation/components/ComposeNewConversationForm.vue`, `NewConversation/ComposeConversation.vue` | «Enviar também por» (`ExtraInboxesSelector`): depois de escolher a caixa, as outras do MESMO tipo por onde o contato pode ser alcançado; enviar cria uma conversa por caixa com a mesma mensagem (`alsoVia` em `createConversation`) e um só aviso, que nomeia as que falharam. WhatsApp com template fica de fora (08/10, cartão 123jpnbcb50) | `compose-also-send-via` · `ComposeNewConversationForm.spec.js`, `ComposeConversation.spec.js` |
| `app/models/contact.rb` | `include WhatsappBroadcastContact`: contato com identificador `…@broadcast` (status e listas de transmissão do WhatsApp, via WAHA) nasce **bloqueado** — conversa nasce resolvida e não reabre (08/10, cartão 123jpnbcb58). A migração `20261008180000` bloqueou os que já existiam | `contact-whatsapp-broadcast-blocked` · `spec/models/contact_spec.rb` |
| `settings/labels/*`, `store/modules/labels.js`, `labels_controller.rb` | ordem manual, visibilidade (de todos / time / só minha), `code: 'title_taken'` para nome repetido; a tela abre ao **agente** (rota com `ROLES` + `CONVERSATION_PERMISSIONS`), que só edita/apaga as pessoais dele, e a lista diz «quem vê» cada uma, por baixo do nome (em coluna empurrava as ações para fora a 390px) | `labels-manual-order` · `labels_controller_spec.rb`, `settings/labels/specs/Index.spec.js` |
| `config/routes.rb` | uma linha: `resources :kanban_next_actions, only: [:index]` ao lado de `raevo_home` — as tarefas dos leads na Agenda (09/10, cartão 123jpnbcb5m). Controlador, tela e serviço são nossos | `agenda-lead-tasks` · `kanban_next_actions_controller_spec.rb` |
| `routes/dashboard/conversation/ConversationView.vue` | com uma conversa aberta abaixo de 1600px, a navegação recolhe a ícones pelo modo de foco (`useRequestSidebarFocus`); a lista **fica** (16/09 escondia-a — revisto a 09/10, ver `raevo-aprovacao.md`). Lê `useWindowSize`; o resto é o ficheiro do upstream | `conversation-list-stays` · `conversation/specs/ConversationView.spec.js` |
| `components/ChatList.vue`, `ChatListHeader.vue` | a lista abre na aba que o agente escolheu (ou na última usada) e lembra a troca em `conversations_filter_by.assignee_tab`; o filtro guardado aberto pode ser fixado como o que abre o painel (`conversations_default_folder_id`), com o botão de alfinete ao lado de editar e apagar; atalho de pesquisa nativo no cabeçalho. A regra vive em `helper/conversationFilterPreferences.js`; no nativo ficam as costuras | `conversation-list-preferences` · `components/specs/ChatList.spec.js`, `ChatListHeader.spec.js` |
| `label_policy.rb`, `labels/update_service.rb`, `labels/destroy_service.rb`, `views/.../labels/*.jbuilder`, `api/labels.js`, `useConversationLabels.js` | visibilidade das etiquetas (o agente cria e gere só as pessoais; o escopo esconde o que a pessoa não vê); renomear e apagar chegam às **oportunidades**; as quatro respostas da API trazem `position`, `visibility`, `team_id`, `created_by_id`; acrescentar ou tirar uma etiqueta numa conversa preserva as que a pessoa não vê | `labels-visibility-and-opportunities` · `labels_controller_spec.rb`, `labels/*_service_spec.rb`, `useConversationLabels.spec.js` |
| `constants/permissions.js`, `enterprise/app/models/custom_role.rb` | as 21 permissões do Pipeline, Financeiro e Marketing nas funções personalizadas — no ecrã (`AVAILABLE_CUSTOM_ROLE_PERMISSIONS`) e na validação do servidor (`CustomRole::PERMISSIONS`) | `raevo-custom-role-permissions` · `constants/specs/permissions.spec.js`, `custom_role_spec.rb`, políticas do Kanban e do Financeiro. O resto do CI corre **sem** o enterprise e estes exemplos saltavam (`if: defined?(CustomRole)`); o último passo do `backend-tests` repõe-no e corre-os, porque a imagem de produção é a EE |

Ao resolver um destes ficheiros: aceitar a versão nova do upstream e **reaplicar só o bloco marcado
`RAEVO`**. Nunca copiar o ficheiro antigo por cima — perde-se o que o upstream corrigiu.

### 4. Aprovar o código e a imagem

- Testar componentes reais nos contratos compartilhados. Stubs de router, traduções e componentes filhos não podem ser a única evidência.
- Para um bug conhecido, demonstrar que o novo teste falha com o comportamento quebrado e passa com a correção.
- Executar CI customizado e testes upstream relevantes. Rodar a jornada Playwright com Rails, assets e API reais, navegando por clique. Não ignorar erros de API ou de console para tornar o smoke verde.
- Revisar screenshots e traces; sucesso de build não comprova disposição visual correta.
- No smoke, concluir uma ação com segundos na data e conferir campos vazios e histórico;
  testar Marketing ligado, desligado e reativado pela configuração sem recarregar a aplicação.
  O estado desativado deve ocultar a entrada operacional, não o acesso de configuração autorizado.
- Publicar somente a imagem do SHA aprovado. Alteração posterior, inclusive resolução de conflito ou tradução, exige nova rodada. O gate de `build_and_push.yml` verifica a rodada mais recente de `custom_checks.yml` do mesmo SHA.

### 5. Aceitar no ambiente publicado

- Aplicar primeiro em staging/canário com backup e image digest registrados. Admin, API e Sidekiq devem usar a mesma imagem e as mesmas chaves de criptografia necessárias.
- Executar migrations uma vez pelo serviço API e conferir `db:migrate:status`. Uma mudança só de frontend não exige migration nova; versões acumuladas podem ter migrations pendentes.
- Navegar por clique no domínio real, sem cache antigo. Repetir os contratos da tabela com uma conta sintética, incluindo caixa com imagem e conta sem imagem.
- Simular criação/edição de oportunidade, agendamento/remarcação, cobrança sandbox, formulário e execução de automação sem enviar mensagens reais a clientes. Testar também permissões de secretária e administrador.
- Verificar edição concorrente e volume representativo antes de ampliar a liberação. Registrar console, respostas de API, screenshot, IDs sintéticos e resultado. Nunca registrar tokens ou dados clínicos nas evidências.
- Se houver regressão, interromper a liberação. Retornar à imagem anterior apenas se compatível com o schema atual; restauração de banco exige decisão e plano próprio. Não executar `db:rollback` às cegas.

### Registro obrigatório da entrega

Copiar este checklist para a entrega/PR, sem marcar resultados não executados:

- [ ] versão upstream, tag de pré-upgrade e SHAs registrados;
- [ ] relatório de overlaps e colisões revisado; nenhum arquivo sem decisão;
- [ ] contratos Superadmin, inbox e módulos Raevo preservados;
- [ ] testes de regressão e navegação real aprovados;
- [ ] capturas/traces revisados e anexados;
- [ ] CI do SHA final aprovado; tag e digest da imagem registrados;
- [ ] migrations, backup e rollback documentados;
- [ ] smoke do domínio publicado e canário aprovados;
- [ ] aceite de produção, pendências e tempo registrados no ClickUp.

### Aprendizado dos incidentes

| Incidente                            | Causa                                                       | Proteção adicionada                                              |
| ------------------------------------ | ----------------------------------------------------------- | ---------------------------------------------------------------- |
| Pipeline/barra lateral desaparecem   | `RouterLink` resolvido sem `to`                             | Teste com router real e smoke por clique                         |
| Contatos falha com WhatsApp          | Lista upstream e mapa Raevo divergentes em merge automático | Traduções reais de todos os perfis + inventário de overlaps      |
| Imagem da caixa ausente em conversas | Nomes snake/camel e identificação escondida com uma caixa   | Componente compartilhado normalizado e testes em cada superfície |
| Imagem publicada antes dos checks    | Build manual independente da validação                      | Gate do CI customizado no mesmo SHA                              |

## Ritmo recomendado

Fazer uma revisão mensal de releases upstream e uma atualização controlada trimestralmente, antecipando patches de segurança e mudanças de canal. Uma atualização deve ser tratada como uma entrega de produto: branch própria, imagem própria, migração explícita e validação canário.
