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

## Ritmo recomendado

Fazer uma revisão mensal de releases upstream e uma atualização controlada trimestralmente, antecipando patches de segurança e mudanças de canal. Uma atualização deve ser tratada como uma entrega de produto: branch própria, imagem própria, migração explícita e validação canário.
