# Auditoria: conclusão de ações e navegação de Marketing

Data: 07/10/2026. Base: `6b7e744138478a905d2957c7d8ce99f56b9a3f88`.
Ramo de entrega: `fix/pos-merge-4.18-e-backlog-thiago`.
Escopo: commits `3e6e61f2a`, `2e0df84e3` e `6b7e74413`, após a auditoria
anterior incorporada em `3047307c7`. Não é conclusão dos cartões de backlog.

## Achados corrigidos

1. **P1: concluir podia deixar os campos preenchidos.** O modelo inferia a intenção
   pela ausência de alterações em tipo/data/observação. O `datetime-local` descarta
   segundos, e o utilizador também pode editar os detalhes antes de concluir.
   A tela agora envia `complete_next_action: true`; o modelo arquiva os detalhes
   e limpa os campos. O atributo é virtual, booleano e consumido nessa conclusão.
   A API permite-o tanto nos parâmetros quanto na seleção de atualização estável.
   Importações, lançamentos retroativos e o fluxo antigo sem alteração de detalhes
   continuam cobertos. A string `false` não é interpretada como intenção verdadeira.
2. **P2: um salvamento comum alterava uma data não editada.** A tela reconstruía
   a data com precisão de minutos. Agora omite esse atributo do PATCH quando o
   controle não mudou, preservando inclusive a precisão que o serializer não expõe.
3. **P2: concluir registrava um agendamento que não existia.** A limpeza dos campos
   acionava o evento `next_action_scheduled` junto com `next_action_completed`.
   Uma ação concluída não emite evento de agendamento; o histórico continua salvo.
4. **P2: Marketing desligado ficava sem entrada para configurar.** A entrada
   operacional permanece oculta quando desligado, mas Configurações oferece o
   acesso a quem pode configurar. Não se ampliaram permissões de backend.
5. **P2: ligar/desligar Marketing deixava o menu desatualizado.** A resposta do
   módulo agora sincroniza o registro da conta usado pela barra lateral, preservando
   seus demais atributos. Respostas tardias após troca de conta são ignoradas.
6. **P2: ativar Marketing não carregava os catálogos de configuração.** Conexões
   e origens não eram buscadas quando a tela iniciava com o módulo desligado.
   A ativação agora carrega os dados sem exigir atualização da página.

O seed de `6b7e74413` estava correto: ligar Marketing na conta sintética mantém a
cobertura da rota. O smoke foi ampliado para verificar também o ciclo desligar,
acessar Configurações e reativar, além da conclusão real de uma ação com segundos.
Os dois contratos foram registrados em `config/raevo/upstream-contracts.json` e
no roteiro obrigatório de atualização do Chatwoot.

## Achado adicional no navegador

O smoke completo encontrou chamadas a `/enterprise/api/v1/accounts/:id/limits`
numa instalação própria. O backend disponibiliza esse endpoint somente no Cloud.
Captain e a tela nativa de upgrade usam a mesma ação do store, `accounts/limits`;
a correção foi centralizada ali, respeitando a condição de Cloud. A chamada no
Cloud continua coberta. Não se ignorou o 404 para passar no smoke. O contrato
também entrou no inventário de upstream.

## Evidências

- Os testes de regressão falharam antes das correções: payload/data do componente,
  campos não limpos na API Rails, evento de agendamento indevido, sincronização de
  Marketing, carregamento dos catálogos e resposta tardia após troca de conta.
- Playwright reproduziu a ausência do acesso de configuração após desligar Marketing.
- RSpec: **195 exemplos, zero falhas**, em banco exclusivo de testes, separado
  do banco da jornada de navegador.
- Listeners, cadências e ações de automação: **39 exemplos, zero falhas** adicionais.
- Vitest: **802 testes, 40 arquivos, zero falhas**, incluindo conversas nativas.
- Auditor de upstream: **7 testes, zero falhas**.
- Playwright com Rails/API reais e assets compilados: **1 jornada completa aprovada**,
  cobrindo navegação, conclusão com milissegundos preservados, configuração e
  reativação de Marketing. Sem erros de página, console ou respostas de API.
- Vite build, RuboCop, Prettier dos arquivos de código/relatório, tokens, pares WCAG,
  placeholders i18n e `git diff --check` aprovados. ESLint sem erros; seis avisos
  preexistentes de i18n em Marketing permanecem. Não se executou toda a suíte upstream.
- Sem migration nova. Nenhum dado de produção foi alterado.

## Limitações e tentativas

Uma rodada RSpec reutilizou o banco semeado para Playwright: dois specs globais
de escopo contaram o card sintético e falharam. A rodada válida usou outro banco
isolado, sem esse seed. Não foram modificados os testes para ignorar o registro.
Uma tentativa de browser usou o padrão de URL errado para aguardar o PATCH
(`cards/id`, em vez de `cards/by_id/id`); outra reutilizou a ordem de etiquetas
alterada pela própria jornada. Os fixtures sintéticos foram restaurados antes
da rodada final. Uma tentativa também procurou indicadores sem sair da configuração
de Marketing; o teste passou a retornar explicitamente ao painel. Essas tentativas
não são consideradas validação aprovada. Uma tentativa também começou antes do
término do build; a jornada aprovada foi executada após confirmar sua conclusão.

Não houve deploy, geração de imagem, alteração do WAHA ou mudança de estado/tempo
no ClickUp. O ambiente publicado precisa receber a nova imagem e ser validado
separadamente. A tela branca de Marketing com os dados específicos da conta de
produção não foi reproduzida nem atribuída a uma causa sem evidência.

## Pendência de segurança confirmada

O log do job `security-scan` do run `37681052140`, SHA `6b7e74413`, confirma
dois avisos High em `ruby_llm 1.15.0`: CVE-2026-67987 e CVE-2026-67989.
A conclusão de Claude sobre o motivo desse check vermelho está sustentada pelo log.
Não se desabilitou o scanner nem se migrou a biblioteca para uma versão major
pré-release nesta correção funcional. Essa pendência permanece no cartão
[RubyLLM / segurança](https://app.clickup.com/t/123jpnbcdax).
Isso impede afirmar que todos os checks upstream estão verdes.
