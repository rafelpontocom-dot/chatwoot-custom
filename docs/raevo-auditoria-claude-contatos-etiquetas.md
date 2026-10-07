# Auditoria Codex: Contatos e Etiquetas

## Escopo e base

Revisao do `AUDITORIA-CODEX.md` da pasta principal e dos commits
`446f1ab95`, `b538bf503`, `0e5d49c41`, `6f81b895a`, `b11e4e5e9` e
`2072009ed`, no ramo `fix/pos-merge-4.18-e-backlog-thiago`.
Base local examinada: `2072009ed14b2f903f65fcdc4ce64b3e80020298`.

O relato do Claude nao foi considerado prova independente de producao.
As correcoes desta passagem sao locais, sem commit, push, imagem ou deploy.

## Achados corrigidos

| Gravidade | Achado | Correcao |
| --- | --- | --- |
| P1 | Filtrar as definicoes do WAHA nao filtrava os valores salvos: o fallback reintroduzia atributos tecnicos, inclusive os que perderam a definicao | Filtrar a lista final de entradas pela mesma regra compartilhada, antes de configurar a visibilidade |
| P1 | Telefone local recebia `+55` sempre, inclusive para Portugal; texto nao numerico virava `+55` | Seletor explicito de pais com nomes localizados; parser e validacao `libphonenumber-js`, ja presente no projeto; enviar E.164 e respeitar DDI informado |
| P1 | Criacao de contato concluida depois de outra busca ou fechamento podia selecionar o contato antigo e buscar suas caixas | Invalidar respostas pela revisao do picker, sem repetir nem cancelar artificialmente uma criacao ja aceita pelo servidor |
| P2 | Nome sugerido aparecia vazio ate receber foco; focar um nome vazio tambem apagava telefone/erro | Preencher na resposta vazia da busca e remover a inicializacao por foco |
| P2 | Reordenar campos visiveis usava o indice da lista original, que ainda continha chaves ocultas | Trocar as posicoes das chaves visiveis; preservar chaves tecnicas e desconhecidas existentes na configuracao |
| P2 | Fechar Etiquetas mantinha escolhas nao salvas, contrariando o relato de descarte | Separar selecao salva de rascunho; restaurar ao fechar por clique fora, botao ou Escape |
| P2 | Escape real no popover propagava para a oportunidade e abria confirmacao de descarte quando havia outra edicao | Impedir propagacao, fechar apenas Etiquetas e devolver foco ao gatilho |

Nada foi apagado do contato, das definicoes de atributos ou do banco.
Ocultar enderecamento do WhatsApp e uma regra de apresentacao, nao uma barreira
de seguranca nem alteracao da integracao.

## Lacunas nos testes anteriores

- O teste de atributos sem colocacao usava definicoes tecnicas, mas nao valores
  tecnicos preenchidos no contato. Testava ausencia de rotulos, nao o caminho
  que reintroduzia os valores.
- O teste de Escape usava `trigger('keydown.esc')`. Isso nao exercitava o
  `event.key === 'Escape'` do manipulador pai como um evento real. O novo teste
  envia `trigger('keydown', { key: 'Escape' })` com edicao comercial pendente.
- O clique fora pode ser testado sem contaminar outros testes: somente esse
  caso monta em um host ligado ao documento, com `unmount()` e remocao do host
  em `finally`. A espera de um turno do event loop corresponde ao bloqueio de
  clique que o VueUse libera via `setTimeout(0)`.
- Os novos casos foram executados antes das correcoes e falharam pelos
  comportamentos descritos; depois, passaram. O teste de reordenacao tambem
  falhou antes de ajustar os indices.

## Verificacao executada

- Vitest ampliado: **34 arquivos, 712 testes, zero falhas**. Abrange os specs do
  Kanban, helpers de contato/caixa e sidebar de Contatos.
- ESLint dos tres componentes e seus tres specs: aprovado.
- Prettier dos arquivos alterados: aprovado.
- Portas `check-design-tokens`, `check-design-pairs`, `design-tokens check` e
  `check_frontend_i18n_placeholders`: aprovadas.
- Jornada Chromium local com o componente Vue e estilos reais, APIs simuladas:
  busca vazia, nome pre-preenchido, pais Portugal, erro de telefone invalido,
  recuperacao para `+351`, escolha de caixa e criacao da oportunidade. Aprovada
  em 1280px e 390px, sem erro de pagina nem rolagem horizontal.
- Capturas revisadas visualmente em `output/audit/` da worktree temporaria.
  Sao evidencia de inspecao local, nao baseline aprovada de regressao visual.

Avisos preexistentes: Browserslist desatualizado, sourcemap ausente de uma
dependencia ProseMirror e aviso Node de modulo em `validate_palette.js`.
Nao foram tratados como falhas nem silenciados por mudancas no produto.

O caminho do checkout contem espacos; ligar seu `node_modules` por symlink na
worktree fazia o Vite falhar ao carregar o setup. As dependencias existentes
foram copiadas para a worktree, sem instalar ou atualizar versoes do projeto.

## O que continua pendente

- Confirmar em nova imagem a aba Contato com valores WAHA preenchidos, com e
  sem colocacao de campos, e atributos sem definicao.
- Confirmar cadastro BR/PT, selecao de caixa, recuperacao de 422 e criacao
  completa na API Rails real. A jornada desta passagem usou APIs simuladas.
- Confirmar Etiquetas com edicao comercial pendente: salvar, fechar, abrir,
  Escape e clique fora. O teste DOM usa o VueUse real; nao houve novo teste
  desta mudanca na tela completa em producao.
- Confirmar o token da caixa ausente no sidebar da imagem em producao.
- A configuracao do WAHA, o comportamento da sessao e a limpeza de status ja
  importados nao foram inspecionados nesta passagem.
- Os outros cartoes descritos como apenas avaliados ou em backlog nao foram
  implementados por esta auditoria.

## Regras para revisoes seguintes

1. Para um filtro de apresentacao, testar definicao e valor real, com/sem
   configuracao, e fallback de valor cuja definicao nao existe.
2. Ao filtrar uma lista editavel, testar tambem seus indices de reordenacao.
3. Teclado deve usar eventos com `key` real e verificar efeitos no pai.
4. Testes ligados ao documento devem limpar seu proprio host e listeners.
5. Criacoes assincronas devem ser testadas depois de busca nova e fechamento.
6. Teste local verde nao autoriza fechar um cartao como validado em producao.

Estas regras complementam o roteiro de
[`raevo-chatwoot-upstream-maintenance.md`](raevo-chatwoot-upstream-maintenance.md).
Nao ha migration nova nesta correcao.
