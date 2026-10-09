# Aceite técnico: upgrade e identidade dos canais

## Escopo

Completar a identificação visual das caixas e validar os três itens compartilhados no ClickUp:

- [Mudar ícone dos canais no Raevo CRM](https://app.clickup.com/t/123jpnbc23z).
- [Corrigir barra de rolagem na tela de Início](https://app.clickup.com/t/123jpnbc240).
- [Permitir reordenar etiquetas manualmente](https://app.clickup.com/t/123jpnbc243).

As implementações anteriores de Claude foram preservadas. Esta entrega complementa a imagem da caixa em conversas e amplia as verificações dos três itens. Os itens permanecem em validação até o aceite no ambiente publicado.

## Correção e limites

`ChannelIcon` aceita dados snake_case e camelCase. A imagem configurada da caixa aparece nas listas Minhas, Não atribuídas e Todos, nos layouts compacto e expandido, incluindo conta com uma única caixa. Histórico de contato/empresa, notificações e resultados de busca usam o mesmo componente. A foto do contato não é substituída. Sem imagem ou com falha de carregamento, o ícone nativo do canal continua disponível; uma caixa API não é inferida como WhatsApp.

O roteiro obrigatório de atualização está em [Manutenção do upstream](raevo-chatwoot-upstream-maintenance.md) e é referenciado no topo do `AGENTS.md`. O catálogo de contratos em `config/raevo/upstream-contracts.json` e o relatório `scripts/raevo-upstream-audit.mjs` complementam o histórico Git. Não há cópia de arquivos antigos sobre o núcleo atualizado.

No relatório da atualização 4.18, a base comum confirmada é `8818d276b954ac4f84cffd8915c99f40e43804ed`: 117 caminhos foram alterados pelos dois lados e nenhuma colisão de timestamp de migration foi encontrada. 98 caminhos não têm contrato cadastrado específico e continuam exigindo a revisão manual do upgrade. A existência de um contrato cadastrado não comprova cobertura completa daquele diretório.

## Evidência local

- RED/GREEN das imagens: antes da correção, 15 cenários falharam; depois, os 24 testes focados passaram.
- Suíte ampliada de frontend: 71 arquivos, 1.108 testes aprovados.
- API de etiquetas: 14 cenários aprovados, incluindo persistência, autorização e isolamento de conta.
- Relatório de upstream: 7 cenários aprovados, incluindo referências inválidas, histórico raso e migrations com o mesmo timestamp.
- Playwright com Rails/Vite e banco sintético isolado: uma jornada aprovada, com navegação por clique, Pipeline, perfil WhatsApp do contato, Início em janela baixa, as três listas de conversas nos dois layouts e ordem das etiquetas persistida após recarregar.
- Screenshots dos layouts compacto e expandido revisadas: imagem da caixa ao lado do contato e imagem preservada na barra de canais.
- Placeholders i18n, tokens de design, lint focado e RuboCop aprovados. Avisos existentes de traduções dinâmicas e deprecações do Rails não foram tratados como erros novos.

## Release e aceite de produção

O commit e a imagem finais devem ser registrados nos comentários das tarefas com links do CI. O build exige os quatro jobs do CI customizado aprovados no mesmo SHA. O tempo desta entrega é registrado como uma entrada adicional, sem substituir o tempo já registrado por Claude.

Nenhuma migration nova foi criada neste complemento. A atualização acumulada já contém `20261003120000_add_position_to_labels.rb`; confirmar `db:migrate:status` antes do deploy e executar `db:migrate` se estiver pendente.

- [ ] Admin, API e Sidekiq na mesma nova imagem/digest.
- [ ] Testar imagem configurada real e caixa sem imagem nas três listas, nos dois layouts.
- [ ] Confirmar Início rolável e ordem das etiquetas após recarregar.
- [ ] Navegar por clique entre módulos com console e respostas de API sem falha.
- [ ] Registrar aprovação do responsável no ClickUp.

A inspeção foi feita com Chromium automatizado isolado, não na sessão de Chrome nem no domínio de produção do usuário. Publicação da imagem não equivale a deploy no Swarm ou aprovação clínica/comercial.
