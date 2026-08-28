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

## Checklist de release

- [ ] versão upstream e SHA Raevo registrados na imagem;
- [ ] migrations listadas e aplicadas somente pelo container `chatwoot_api`;
- [ ] `db:migrate:status` sem pendências;
- [ ] testes customizados e lint concluídos;
- [ ] fluxos canário: conversa, oportunidade, agendamento, cobrança e automação;
- [ ] rollback definido para a imagem anterior e nenhuma migration destrutiva sem plano reversível.

## Ritmo recomendado

Fazer uma revisão mensal de releases upstream e uma atualização controlada trimestralmente, antecipando patches de segurança e mudanças de canal. Uma atualização deve ser tratada como uma entrega de produto: branch própria, imagem própria, migração explícita e validação canário.
