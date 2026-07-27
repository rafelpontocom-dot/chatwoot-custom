# PRD: Fluxos Visuais Do Kanban

## Contexto

O Kanban comercial do Chatwoot precisa automatizar etapas repetitivas de venda sem transferir a equipe para N8N, Kommo ou planilhas. O administrador deve conseguir entender uma regra olhando para um fluxo, enquanto a equipe comercial recebe ações claras e auditáveis na oportunidade.

O produto não é um clone genérico de ferramentas de automação. Ele é um construtor de processos comerciais limitado aos dados, permissões e canais que o board já conhece.

## Objetivo

Permitir que administradores criem automações seguras para oportunidades: iniciar por um evento comercial, esperar, avaliar condições, enviar uma mensagem compatível ou executar uma ação no card.

## Não Objetivos

- executar JavaScript, código Liquid arbitrário ou scripts de usuário;
- armazenar chaves de serviços externos no fluxo;
- substituir o N8N em integrações complexas nesta fase;
- executar loops, junções paralelas, código ou jornadas multicanal genéricas sem simulação e auditoria;
- enviar WhatsApp fora da janela de atendimento sem template aprovado.

## Perfis

**Administrador comercial:** configura regras, testa com uma oportunidade e acompanha execuções.

**Secretária ou vendedor:** trabalha no card e vê o resultado da automação, sem precisar editar o fluxo.

**Gestor:** audita o que foi enviado, executado, ignorado ou falhou.

## Fluxo Da Experiência

1. O administrador abre Kanban > Automações do funil pelo ícone de raio no cabeçalho.
2. A central mostra Fluxos, Lembretes, Conexões e Execuções, com os itens existentes em listas curtas e escaneáveis.
3. Seleciona uma automação, usa Nova automação ou parte de um modelo pronto para abrir o construtor em uma área dedicada.
4. Define nome e abre o resumo do gatilho na única barra operacional do fluxo. Evento e critérios compatíveis ficam no popover contextual; reentrada e condições posteriores são opções avançadas recolhidas. Publicar, validar, testar, cancelar e salvar vivem nessa mesma barra, para o canvas não começar sob cabeçalhos duplicados.
5. Usa a paleta pesquisável à esquerda para escolher um bloco por categoria, ou arrasta o bloco para o canvas. O botão `+` permanece como atalho contextual e alternativa em telas pequenas.
6. Seleciona um nó ou conexão para configurar seu conteúdo em um diálogo flutuante, sem comprimir o canvas.
7. Salva. O backend valida todos os nós antes de ativar a regra.
8. Quando o evento ocorre, a execução fica registrada no histórico do funil, com estado, oportunidade e motivo de falha.
9. Se houver uma espera, o card segue operando normalmente; a execução retoma no horário salvo.

## Princípios Da Central De Automações

- O canvas é uma área de trabalho, não um bloco dentro de um formulário longo.
- A paleta lateral é recolhível, pesquisável e organizada por categorias; ela não despeja todos os nós de uma vez e preserva as categorias abertas pela pessoa enquanto a tela é atualizada.
- O botão `+` é uma alternativa contextual: insere e conecta o próximo passo no caminho selecionado.
- O diálogo de configuração aparece somente para o nó ou conexão selecionado, concentra suas propriedades e preserva a largura do canvas. No desktop, abre centralizado com até `44rem`; no mobile, ocupa a viewport com margens seguras.
- Lembretes de consulta são configurados em uma aba própria; follow-up comercial é um fluxo visual, nunca uma segunda configuração paralela.
- Conexões externas têm configuração própria: o fluxo apenas escolhe uma conexão já aprovada.
- Execuções permitem retry de falhas, cancelamento de esperas e leitura rápida do impacto na oportunidade.
- O inseridor contextual `+` acrescenta e conecta o próximo passo no caminho selecionado; a paleta pode ser recolhida para o canvas ocupar toda a tela quando necessário.
- O fluxo nasce como rascunho e só é ativado depois de validado e revisado por um administrador. Cada salvamento cria uma versão visível para auditoria; execuções mantêm o snapshot da versão que as iniciou. Restaurar uma versão pede confirmação explícita, cria uma nova versão e só afeta execuções futuras.
- Cadências legadas permanecem somente para preservar histórico e regras existentes; novas cadências não são criadas pela central.
- `Follow-up comercial` e `NPS e avaliação Google` são sempre abertos como rascunho. `Mensagem de aniversário` abre sua configuração específica, desativada por padrão, pois depende da data de nascimento do contato.

## Catálogo De Nós Do Produto

O catálogo não replica o n8n. Ele cobre eventos, decisões e ações comerciais que existem no Chatwoot/Kanban; integrações, IA, transformação extensa de dados e processos entre sistemas continuam no N8N por uma conexão aprovada.

### Implementados Ou Em Consolidação

| Nó                | Finalidade                                                         | Configuração obrigatória   |
| ----------------- | ------------------------------------------------------------------ | -------------------------- |
| Gatilho           | Início visual do fluxo; o evento continua configurado na regra.    | Um por fluxo.              |
| Aguardar          | Pausa a execução por horas.                                        | Número positivo de horas.  |
| Aguardar intervalo | Distribui o próximo passo em um minuto aleatório dentro de uma faixa. | Mínimo e máximo positivos em minutos. |
| Aguardar até data | Agenda em relação a um campo de data/hora da oportunidade; pode parar ou seguir por `Data indisponível` quando o valor não puder ser usado. | Campo, deslocamento e política de falha. |
| Aguardar resposta | Pausa até uma resposta recebida do cliente, ou até vencer o prazo; opcionalmente divide o fluxo entre `Resposta recebida` e `Prazo da resposta vencido`. | Limite positivo em horas e política de prazo. |
| Aguardar horário comercial | Mantém a execução até a próxima janela de trabalho configurada. | Dias, horário inicial/final e fuso. |
| Enviar mensagem   | Envia WhatsApp ou e-mail na conversa compatível do contato.        | Canal, opt-in e texto.     |
| Ação comercial    | Atualiza a oportunidade ou registra o próximo trabalho do time.    | Tipo e parâmetros da ação. |
| Enviar webhook    | Envia dados da oportunidade para uma conexão HTTPS já configurada. | Conexão ativa.             |
| Roteador          | Avalia regras ordenadas e segue a primeira saída correspondente.   | Saídas, regras E/OU e rota `Caso contrário`. |
| Distribuir caminhos | Alterna saídas sequencialmente para testes ou campanhas.          | Duas ou mais saídas.       |
| Fim               | Encerra o caminho.                                                 | Nenhuma.                   |

As ações comerciais disponíveis são: mover etapa, definir responsável, distribuir novos cards em rodízio, criar próxima ação, preencher, incrementar ou limpar campo personalizado, arquivar oportunidade, adicionar/remover etiqueta e registrar nota interna na conversa vinculada.

### Próximos Nós Comerciais

| Categoria | Nó | Resultado para o operador |
| --- | --- | --- |
| Gatilhos | Agenda recorrente | Executa uma verificação diária, por exemplo aniversário ou tarefas vencidas. |
| Decisão | Filtro | Atalho de uma rota condicional com uma única continuação válida. |
| Decisão | Elegibilidade de mensagem | Verifica consentimento, canal, janela de 24 horas e etapa antes de qualquer envio; o nó de mensagem pode seguir por uma saída explícita de não enviada. |
| Tempo | Aguardar inatividade | Continua somente após o cliente não responder pelo período configurado; opcionalmente divide o fluxo entre `Nenhuma resposta recebida` e `Cliente respondeu`. |
| Decisão | Continuar na etapa do gatilho | Interrompe silenciosamente a cadência quando a oportunidade sai da etapa selecionada no gatilho. |
| Tempo | Horário comercial | Aguarda a próxima janela válida; opcionalmente divide o fluxo entre `Janela de atendimento disponível` e `indisponível` quando a janela não puder ser calculada. |
| Cliente | Transferir para humano | Encaminha a conversa para uma equipe comercial, um responsável ou ambos; adiciona contexto e interrompe mensagens automáticas. |
| Cliente | Atualizar contato | Atualiza atributo permitido, como opt-in ou data de nascimento. |
| Oportunidade | Ganhar ou perder | Fecha a oportunidade com dados obrigatórios e motivo quando aplicável. |
| Oportunidade | Concluir próxima ação | Registra a nota de conclusão e pode agendar a próxima atividade comercial. |
| Operação | Registrar execução | Adiciona uma observação imutável à linha do tempo, sem expor dados técnicos ao cliente. |
| Operação | Tratar falha | Define parar, tentar novamente ou seguir pela saída de falha para nós permitidos. |

### Fora Do Escopo Do Construtor

- código JavaScript, shell ou expressões arbitrárias;
- requisição HTTP arbitrária, banco de dados, arquivo e credencial no fluxo;
- loop/iteração genérico, merge/join, paralelismo e subworkflows;
- IA de propósito geral sem contrato de entrada, saída, custo e revisão humana;
- integrações entre sistemas que não usam conexão declarada e aprovada.

O modelo `Follow-up comercial` começa em rascunho e representa uma cadência de orçamento: espera 2, 2, 3 e 7 dias sem resposta, confirma que o card ainda está na etapa de entrada, aguarda o horário comercial, aplica uma distribuição aleatória de 10 a 30 minutos, envia uma mensagem editável e incrementa um campo numérico escolhido pelo administrador. A resposta do cliente interrompe os próximos contatos. Mensagens externas exigem sempre um nó `Enviar mensagem`, com opt-in e as regras do canal.

## Regras De Mensagem Externa

- Mensagem exige opt-in explícito no atributo do contato configurado pelo administrador.
- WhatsApp usa uma conversa compatível e somente envia quando ela pode receber resposta livre.
- Fora da janela de 24 horas, o envio livre é bloqueado; a execução só prossegue quando o nó possui um template oficial de WhatsApp configurado.
- E-mail exige uma conversa de e-mail compatível.
- Ausência de conversa, opt-in ou janela não causa repetição infinita: fica registrada como `skipped` no histórico e o fluxo continua.
- A mensagem permite nome do contato, título e valor da oportunidade e campos personalizados autorizados. O inseridor pesquisável mostra apenas variáveis disponíveis para aquele board; tokens desconhecidos permanecem literais e nunca executam código.
- Horário silencioso e intervalo mínimo entre mensagens podem ser configurados no nó. Quando aplicáveis, a execução fica aguardando e retoma automaticamente no próximo horário permitido.

## Regras De Confiabilidade

- Uma execução é idempotente por regra e evento comercial.
- Esperas são persistidas; nenhum processo fica aberto aguardando tempo.
- Desativar a regra antes da retomada impede a continuidade e registra a execução como ignorada.
- Arquivar a oportunidade antes da retomada também interrompe o fluxo.
- A configuração deve rejeitar referências a etapas, agentes e campos fora do board ou conta.
- Webhooks só aceitam HTTPS sem credenciais na URL, têm timeout curto, não seguem redirecionamentos e usam assinatura HMAC.
- Um fluxo possui no máximo 50 nós executáveis por rodada, não aceita ciclos e não executa código do usuário.
- Cada execução recebe um snapshot imutável do gatilho, condições, ações e canvas no momento em que é criada. Edições posteriores não mudam uma mensagem já agendada.
- Ao alterar uma regra com execuções aguardando, o administrador pode cancelá-las explicitamente. Sem essa opção, elas terminam com o snapshot da versão que as iniciou.
- O histórico de versões permite restaurar uma configuração anterior, mas a ação precisa de confirmação e sempre cria outro snapshot, preservando a auditoria linear.
- Uma oportunidade não pode reentrar na mesma automação enquanto já houver execução ativa. Depois de concluída, a reentrada só acontece se o administrador habilitar a opção correspondente na regra.

## Estados Visíveis

| Estado     | Significado                                                        |
| ---------- | ------------------------------------------------------------------ |
| Em fila    | Evento recebido, ainda não iniciado.                               |
| Executando | Um job está processando os nós.                                    |
| Aguardando | Parado em um nó de espera, com data agendada.                      |
| Concluído  | Chegou ao nó Fim.                                                  |
| Ignorado   | Regra desativada, oportunidade inativa ou envio sem pré-requisito. |
| Falhou     | Erro técnico registrado para diagnóstico.                          |

## Critérios De Aceite P0

- Criar, editar e salvar um fluxo linear válido.
- Criar uma conexão HTTPS e receber a chave de assinatura uma única vez.
- Inserir um nó pelo `+` e manter as conexões válidas depois da inserção.
- Rejeitar fluxo com nó desconhecido, ids duplicados ou conexão inválida.
- Aguardar e retomar na data persistida.
- Executar cada ação comercial com referências válidas.
- Não enviar mensagem sem opt-in, conversa compatível ou janela de WhatsApp.
- Interromper execução pendente quando a regra for desativada ou o card arquivado.
- Mostrar textos da interface em Português Brasil e manter traduções em inglês para a base do produto.
- Funcionar com mouse, teclado e foco visível nos controles do construtor.
- Ao tentar salvar um fluxo inválido, destacar o nó responsável, abrir sua configuração e preservar o restante do canvas para correção.

## Evolução Planejada

### P1

- Prévia do que será alterado ou enviado antes de salvar. Implementado pela ação Testar, sem efeitos colaterais.
- Teste da regra com uma oportunidade selecionada e relatório por nó. Implementado.
- Cancelamento manual de uma execução em espera. Implementado.
- Horários silenciosos e limite de frequência. Implementado para mensagens do fluxo.
- Template oficial de WhatsApp e seleção de idioma. Implementado no nó de mensagem.
- Compositor de mensagem com emoji, busca de variáveis, preview de balão e imagem. Implementado para nós de fluxo e mensagens de aniversário; imagens usam upload assinado, nunca URL externa.
- Histórico visual por oportunidade, com ator e horário. Implementado na linha do tempo da oportunidade.
- Recepção de webhook de entrada, somente com assinatura e mapeamento explícito para oportunidade. Implementado sem código arbitrário: uma conexão inicia somente regras do evento `Webhook recebido` para o card informado. O limite de taxa é configurado na borda de produção (Traefik/API gateway).

### P2

- Roteador com saídas ordenadas, regras E/OU por saída e rota `Caso contrário`. Implementado.
- Ramificação explícita, sem ciclos implícitos e com uma única rota ativa por execução. Implementado.
- Nó de data de campo: por exemplo, `Data e hora da consulta - 24h`. Implementado.
- Modelos comerciais por objetivo, iniciados em rascunho e adaptados pelo administrador. Implementado para follow-up, NPS/Google e aniversário.
- Ações de lembrete de consulta reutilizáveis no mesmo canvas. Implementado com nós de data, atraso e horário comercial.
- Agenda recorrente, inatividade, transferência humana, atualização de contato e resultado terminal da oportunidade.
- Histórico de execução por nó, tratamento de falha e simulação rica. O histórico mostra passo, saída, estado, horário e motivo seguro no inspector contextual; a simulação resolve condições, rotas e variáveis sem efeitos externos.

## Referências E Estratégia

### Sistemas que orientam a experiência

| Referência            | O que adotar                                                                                                         | O que evitar                                                            |
| --------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| HubSpot Workflows     | Separar gatilho de inscrição, condições de reentrada, agenda e saída do fluxo.                                       | Um catálogo enorme de objetos e regras que não existem no Chatwoot.     |
| Pipedrive Automations | Inserção progressiva por `+`, sequência clara de condição/ação/espera e decisão explícita sobre execuções pendentes. | Limites de produto arbitrários e editor espalhado em muitos painéis.    |
| n8n                   | Nó compacto com estado, configuração contextual, preview/teste e histórico por etapa.                                | Código, shell, arquivos e HTTP arbitrário dentro de um funil comercial. |
| Node-RED              | Paleta pesquisável por categorias, composição por blocos e roteador com regras ordenadas e rota padrão.               | Visual técnico e painel permanente que reduz o espaço do canvas.        |

HubSpot documenta gatilhos por evento, filtro, agenda e webhook e trata reentrada como uma configuração explícita. Pipedrive limita a próxima escolha útil a condição, ação ou espera e pede o tratamento das execuções pendentes quando a automação muda. O n8n mostra a importância de registrar execuções e de auditar nós potencialmente perigosos. [HubSpot: criar workflows](https://knowledge.hubspot.com/workflows/create-workflows), [Pipedrive: atraso e pendências](https://support.pipedrive.com/en/article/workflow-automations-delay-feature), [n8n: auditoria de segurança](https://docs.n8n.io/hosting/securing/security-audit/).

### Três lentes de produto

- **Luke Wroblewski:** divulgação progressiva. O administrador vê a próxima escolha útil, não uma parede de blocos e propriedades.
- **Erika Hall:** linguagem e evidência. Cada nó diz o que fará, quais dados utiliza e por que foi ignorado ou falhou.
- **Ryan Singer:** escopo fechado. O módulo resolve processos comerciais recorrentes e delega integrações complexas ao N8N por webhook assinado.

### Plano de produto revisado

**P0 operacional:** gatilhos de oportunidade e de resposta do cliente; nós de espera, horário comercial, condição, mensagem, ação, nota, etiqueta e webhook; conexões HTTPS aprovadas; histórico de execução; canvas com inserção contextual e modal de configuração do nó. O compositor de mensagem permite texto, emoji, campos pesquisáveis e uma imagem com prévia.

Erros de configuração não podem exigir que o administrador procure pelo canvas: a validação seleciona, destaca e abre a etapa que precisa ser corrigida.

**P1 de governança:** snapshot por execução, decisão ao alterar execuções pendentes, reentrada configurável, supressão/saída, teste guiado com uma oportunidade ativa e passos previstos sem efeitos externos, histórico por oportunidade e webhook de entrada autenticado e mapeado a uma oportunidade existente. Cada salvamento agora cria uma versão imutável, exibida na central e restaurável sem alterar execuções já em andamento.

**P2 de escala:** tarefas internas com prazo, templates por segmento e integrações declarativas adicionais, sempre por conexão aprovada. O rodízio de responsáveis está implementado como uma ação atômica do fluxo; a central já exibe saúde operacional com falhas e esperas vencidas.

O Vue Flow é a infraestrutura de interação: oferece zoom, seleção, nós/arestas customizados, controles e minimapa. O produto continua responsável pela linguagem comercial, validação e segurança. [Vue Flow](https://vueflow.dev/)

### Modelo Do Editor Visual

O editor combina a arquitetura do Node-RED com a leitura visual do n8n, sem reutilizar código de produtos com licença incompatível. A paleta lateral é um catálogo independente, pesquisável e recolhível por categoria: Gatilhos, Decisão, Tempo, Cliente, Oportunidade, Integrações e Operação. Um bloco pode ser clicado ou arrastado para o canvas; clique continua sendo a alternativa acessível ao arraste.

#### Direção visual aprovada: Fusão CRM

Esta direção não é uma soma de pequenos ajustes sobre a tela de configurações. O editor deve parecer um produto próprio de automação comercial, mantendo os contratos, permissões e tokens do Chatwoot. A composição usa cinco camadas deliberadas:

1. **Chatwoot:** identidade, tokens semânticos, componentes e linguagem já conhecidos pela equipe.
2. **Frappe CRM:** densidade operacional, superfícies discretas e foco no trabalho repetido de vendas.
3. **Kommo:** termos comerciais, configuração progressiva e decisões fáceis para quem não é técnico.
4. **Node-RED:** paleta pesquisável, categorias recolhíveis e construção do fluxo por blocos.
5. **n8n como referência de UX:** canvas dominante, configuração contextual flutuante e feedback de teste/histórico sem perder o fluxo de vista.

O resultado não deve reproduzir visual ou código de nenhum desses produtos. Ele deve tornar claro, no primeiro olhar, onde descobrir blocos, onde montar o fluxo e onde configurar o passo selecionado.

Esta é a direção única para as próximas entregas, e não uma referência opcional. Ela combina a arquitetura de descoberta do Node-RED com a clareza de configuração do n8n, adaptadas ao dashboard do Chatwoot:

- **Esquerda:** paleta compacta de aproximadamente 196 px, com busca, categorias recolhíveis, ícones e uma linha por bloco. Ela existe para descobrir e adicionar passos, não para explicar cada configuração.
- **Centro:** canvas é a superfície dominante. Mantém fundo discreto, controles agrupados, zoom, minimapa apenas quando necessário e espaço suficiente para montar caminhos reais sem uma coluna permanente de formulário.
- **Nós:** cards densos e estáveis, com faixa semântica de categoria, ícone, título, resumo de uma linha e estado. Condições detalhadas, formulários e textos longos ficam fora do card; saídas continuam rotuladas e acessíveis.
- **Configuração:** clicar em nó ou conexão abre um diálogo contextual centralizado. No desktop ele tem até `44rem`, suficiente para regras, listas e prévias sem rolagem horizontal; no mobile ocupa a viewport com margens seguras. Ele sobrepõe o canvas, não reduz seu espaço. O cabeçalho mostra categoria, título e estado da etapa; `Configurar`, `Testar` e `Histórico` são abas igualmente distribuídas do mesmo contexto e aceitam setas, Home e End no teclado.
- **Ações:** inserir, conectar, excluir, desfazer, refazer e organizar ficam junto ao canvas. O `+` abre um seletor contextual e não depende de hover ou arraste; no mobile, abre a paleta categorizada em drawer. Ao selecionar uma conexão, o inspector mostra origem e destino reais, em vez de um título genérico.
- **Linguagem:** a UI usa termos comerciais curtos, estado compreensível e dados da oportunidade. Não expõe jargão de automação, chaves técnicas ou formulários completos no canvas.
- **Entrada:** modelos comerciais usam ícone, título e descrição curta; regras existentes mantêm estado, edição explícita, teste e histórico em uma linha compacta, sem virar uma lista de formulários.

O resultado precisa parecer uma ferramenta CRM nativa e densa: a eficiência estrutural do Node-RED, a legibilidade e configuração por contexto do n8n e a linguagem do Kanban comercial. Não é permitido copiar componentes ou código do n8n.

### Contrato Do Diálogo De Configuração

- Todo nó e toda conexão usam o mesmo diálogo; não existe painel lateral permanente para nenhum tipo de configuração.
- O diálogo é uma etapa de edição: a pessoa configura, testa ou consulta o histórico e então fecha para retomar o canvas. Campos extensos, como saídas condicionais, usam somente rolagem vertical dentro do diálogo.
- O diálogo mantém o foco internamente, fecha por `Escape`, botão de fechar ou clique no fundo e devolve o foco ao nó ou conexão que o abriu. As alterações ficam no rascunho do fluxo até a pessoa salvar ou cancelar a regra.
- O cabeçalho e as abas ficam visíveis durante a rolagem. Ações destrutivas, conexão e fechamento têm rótulo acessível e confirmação quando houver risco de perda.

As conexões aprovadas para webhook possuem uma trilha administrativa independente da execução do fluxo. A equipe consegue verificar criação, alteração, remoção e regeneração de segredo sem transformar URLs, tokens ou conteúdo externo em dados visíveis no CRM.

O canvas é a área dominante. Clicar em um nó abre uma configuração contextual flutuante, sem comprimir o fluxo. O histórico de teste e execução é solicitado pelo administrador, em vez de ocupar uma coluna fixa. Nós exibem ícone, categoria, título, resumo, estado de validação e conectores de entrada/saída. O Router avalia saídas em ordem; cada saída tem seu próprio grupo E/OU e existe uma rota final `Caso contrário`.

Cada nó usa tamanho estável, cabeçalho com ícone e cor semântica de categoria, uma linha de resumo e chips para a configuração principal. Formulários não aparecem dentro do canvas. Arestas mostram o nome da saída e, ao foco ou hover, oferecem ações de remover ou inserir um bloco no meio. A cor nunca é o único indicador de estado: erro, rascunho, aguardando e concluído também usam texto e ícone.

O painel do nó possui as abas `Configurar`, `Testar` e `Histórico`. O primeiro campo sempre explica o efeito comercial do nó; opções avançadas ficam recolhidas. O painel usa o título real do nó, por exemplo `Configurar roteador`, e nunca um rótulo genérico como `Configurações da etapa`.

A [auditoria do editor e do catálogo n8n](kanban-visual-workflows-editor-audit.md) é a fonte de decisão para a evolução dos nós. Ela separa nós comerciais nativos, integrações que permanecem no n8n por webhook aprovado e capacidades que não entram no produto por segurança, governança ou escopo.

## Métricas

- Quantidade de regras ativas por board.
- Taxa de execuções concluídas, ignoradas e falhas por nó.
- Tempo entre evento e retomada de uma espera.
- Mensagens bloqueadas por falta de opt-in ou janela do WhatsApp.
- Tempo de configuração de uma automação simples pelo administrador.

## Riscos E Decisões

Um canvas permite desenhar fluxos muito mais rápido do que escrever regras, mas também pode esconder complexidade. Por isso, não permite código, valida tudo no servidor e limita o grafo a 50 nós sem ciclos. Integrações externas usam conexões HTTPS separadas e assinadas; não há URL ou segredo solto dentro de um card do fluxo.
