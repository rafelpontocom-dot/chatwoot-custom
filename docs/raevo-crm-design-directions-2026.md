# Direcoes de Design Raevo CRM

Data: 28 de agosto de 2026
Escopo: Kanban, Agenda e Financeiro

## Diagnostico

O produto atual ja tem capacidade funcional relevante, mas ainda mistura tres linguagens: configuracao administrativa, operacao da secretaria e analise do gestor. Isso torna a interface maior, mais explicativa e mais tecnica do que precisa ser. A proxima fase deve substituir a acumulacao de paineis por uma linguagem consistente de trabalho: contexto visivel, informacao sob demanda e acoes no ponto em que a decisao acontece.

## Tendencias que importam

- **Densidade calma:** produtos operacionais estao reduzindo ornamento sem reduzir informacao. Lista, quadro e agenda devem compartilhar filtros e contexto, em vez de abrir paginas paralelas. O Attio trata Kanban como uma visualizacao configuravel de registros, e nao como um produto isolado. [Attio: views Kanban](https://attio.com/help/reference/managing-your-data/views/create-and-manage-kanban-views)
- **Trabalho por teclado sem perder o mouse:** Linear combina quadro, lista, selecao multipla, comando e uma pre-visualizacao leve. Isso e particularmente util para secretaria e comercial, que repetem as mesmas acoes muitas vezes ao dia. [Linear: Board layout](https://linear.app/docs/board-layout), [Linear: selecao](https://linear.app/docs/select-issues)
- **IA contextual, nao uma nova tela:** a tendencia relevante para software empresarial e assistencia dentro da tarefa, com explicacao e controle humano. A IA deve resumir, sugerir e avisar no momento certo, sem competir com a operacao. [SAP Design: Future of Enterprise UX](https://www.sap.com/design/stories-resources/the-future-of-enterprise-ux)
- **Divulgacao progressiva:** configuracoes, filtros avancados e dados secundarios aparecem quando solicitados. A propria Atlassian recomenda introduzir mudancas no contexto da tarefa e permitir que usuarios avancados descubram recursos de forma progressiva. [Atlassian Design](https://atlassian.design/patterns/first-impressions/)
- **Acessibilidade deixa de ser acabamento:** WCAG 2.2 adiciona requisitos para foco nao oculto, alternativa a arrastar e alvos de ponteiro com tamanho minimo. O Raevo deve transformar isso em qualidade perceptivel: foco evidente, atalhos, botoes claros e caminhos alternativos. [W3C: WCAG 2.2](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/)

## Regras comuns, independentemente da direcao

1. A marca usa Carvao para estrutura, Pedra e Areia para superfices calmas, Ciano para acao e Champagne para enfase editorial. Verde, amarelo e vermelho sao exclusivamente estados de negocio.
2. Sora permanece em titulos e valores de alta importancia; Inter permanece em dados, controles e leitura longa.
3. Um cabecalho operacional: contexto atual, busca, filtros, visualizacao e uma acao primaria. Metricas e configuracao nao disputam esse espaco.
4. Oportunidade abre em detalhe lateral fechavel, nao em modal que interrompe o quadro. A conversa aparece no mesmo detalhe como aba ou painel temporario.
5. Campos deixam de ser caixas repetidas. Eles sao linhas editaveis com rotulo dentro do proprio controle; abas organizam dominios e grupos apenas quando houver volume real.
6. Agenda tem dia/semana como superficie principal. Procedimentos, recursos e regras vivem em Configuracoes da Agenda, separados do trabalho diario.
7. Financeiro e uma fila de cobrancas, nao um dashboard de cartoes. Totais ficam em faixa resumida; status, vencimento e acao sao legiveis na primeira passada de olhos.
8. Nenhuma acao critica depende de arrastar. Quadro, agenda, filtros e detalhes precisam de caminho por teclado e foco com contraste.

## As cinco direcoes

### 1. Sala de Operacoes

**Tese:** uma bancada comercial acolhedora, mas de alta concentracao. O quadro ocupa a tela; detalhe de oportunidade entra pela direita sem apagar o contexto.

- Kanban: colunas enxutas, cards de duas camadas, uma acao visivel por card.
- Agenda: mesma navegacao e uma grade semanal grande; detalhe abre no mesmo painel lateral.
- Financeiro: lista com sinais pequenos e uma faixa de totais.
- Personalidade: papel quente, divisores finos, Ciano reservado para trabalho ativo.
- Vantagem: equilibrada para venda por WhatsApp, clinica e financeiro.
- Risco: se o drawer virar formulario longo, perde o beneficio. Limitar cada aba a informacao de decisao.

### 2. Mesa Clinica

**Tese:** o tempo e a pessoa, nao o card, sao o centro da interface. A secretaria inicia pelo dia e acompanha o funil sem parecer que esta em um CRM generico.

- Kanban: uma coluna de agenda de hoje acompanha as etapas comerciais.
- Agenda: trilho de horario, consulta, profissional e acao de confirmacao se leem como uma unica linha de trabalho.
- Financeiro: cobra no contexto da consulta, com estado de pagamento muito claro.
- Personalidade: Pedra, Areia e muito espaco controlado; Ciano pontua atendimento ativo.
- Vantagem: excelente para clinicas, recorrencia e preparacao de consulta.
- Risco: para vendas B2B de alto volume, precisa alternar para Lista com facilidade.

### 3. Terminal de Receita

**Tese:** um CRM de ritmo alto. A lista e a forma padrao de trabalhar; Kanban e uma lente de acompanhamento, nao a unica verdade.

- Kanban: cards compactos e colunas sem decoracao; selecao multipla e barra de acoes aparecem sob demanda.
- Agenda: lista de horarios com uma timeline lateral, adequada a encaixe e remarcacao rapida.
- Financeiro: tabela forte, com vencimento, status e proxima acao na mesma linha.
- Personalidade: Carvao dominante, texto claro e Ciano preciso. Sem sombras e sem superficies flutuantes.
- Vantagem: melhor para equipe comercial, filtros, volume e previsibilidade.
- Risco: exige boa hierarquia tipografica para nao ficar frio ou parecer painel tecnico.

### 4. Atlas de Relacionamento

**Tese:** a oportunidade e uma historia em movimento. Em vez de cartoes grandes, cada entidade se encaixa numa linha do tempo comercial com proxima decisao sempre explicita.

- Kanban: faixas por etapa com cards horizontais, responsavel e proxima acao como primeiro sinal.
- Agenda: agenda e linha do tempo se unem, mostrando consultas, respostas e cobrancas numa mesma escala temporal.
- Financeiro: cobranças entram na historia do relacionamento, nao em uma area isolada.
- Personalidade: composicao editorial, Champagne como marcador de momento, tipografia mais expressiva.
- Vantagem: muito facil para medico e secretaria entenderem o que aconteceu e o que vem agora.
- Risco: precisa manter a Lista como alternativa para operacoes de lote.

### 5. Estudio Modular

**Tese:** um espaco adaptavel por perfil, com blocos funcionais e nao uma colecao de cards. A pessoa monta o contexto, o sistema preserva a consistencia.

- Kanban: barra contextual recolhivel, quadro dominante e painel de detalhe temporario.
- Agenda: calendario central com uma coluna de pendencias e recursos que pode ser escondida.
- Financeiro: resumo horizontal e tabela abaixo; detalhes surgem como painel, nao rota separada.
- Personalidade: superfice clara e modular, bordas estruturais, Ciano e Champagne como pontos de interacao.
- Vantagem: flexivel para contas clinicas e comerciais sem criar dois produtos.
- Risco: configurabilidade demais pode confundir. O P0 precisa entregar tres layouts prontos: Secretaria, Comercial e Gestao.

## Recomendacao

Usar a **Sala de Operacoes** como base Raevo e incorporar dois elementos das demais propostas:

- da Mesa Clinica, a abertura de Agenda baseada em tempo e paciente;
- do Terminal de Receita, Lista como primeira classe, busca global, selecao e comandos;
- do Atlas, uma linha do tempo que responda sempre “o que aconteceu” e “qual e a proxima decisao”.

O Estudio Modular fica como evolucao P1, depois que a base tiver consistencia suficiente para nao transformar cada conta em uma interface diferente.

## Decisoes para aprovar antes de implementar

- Escolher uma direcao principal e ate dois elementos complementares.
- Aprovar densidade de card: compacto por padrao, detalhes apenas no drawer.
- Aprovar o papel do Carvao: navegacao estrutural somente ou superficie de trabalho do Terminal de Receita.
- Definir se `Hoje` sera uma visao transversal obrigatoria para todas as contas.
- Definir tres layouts por perfil para o futuro Estudio Modular, em vez de permitir montagem totalmente livre.

## Porta de qualidade para a implementacao

1. Prototipo aprovado por secretaria, medico e gestor antes de codificar a tela real.
2. Cada modulo recebe uma especificacao de estados: vazio, carregando, erro, sucesso, permissao insuficiente e alto volume.
3. Teste visual desktop em 1280px, tablet em 1024px e teste de teclado em todas as acoes primarias.
4. Foco visivel, alvos de pelo menos 24px e alternativa a arrastar conforme WCAG 2.2.
5. Nenhum novo componente entra sem token semantico, rotulo acessivel, tooltip para icone e verificacao de contraste.
