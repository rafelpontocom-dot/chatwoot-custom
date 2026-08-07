# PRD: Kanban Comercial no Chatwoot

Status: fonte de verdade do produto

Execucao: [Roadmap do Workspace Comercial](./kanban-commercial-workspace-roadmap.md)

Agenda de consultas e recorrencias: [PRD da Agenda Operacional](./kanban-calendar-prd.md) e [Spec da Agenda Operacional](./kanban-calendar-spec.md). O P0 esta em implementacao; o Kanban conserva `starts_at` apenas como compatibilidade ate a migracao planejada.

Este documento define a direção do Kanban comercial do nosso Chatwoot. Ele deve guiar escopo, decisões técnicas, UX e priorização.

## Tese

Não vamos recriar um CRM completo dentro do Chatwoot.

Vamos transformar o Kanban em uma ferramenta comercial leve, personalizável e 100% focada em venda por conversa, capaz de substituir o uso operacional do Kommo para acompanhar leads, oportunidades, próximos passos e fechamentos.

## Objetivo

Permitir que o time comercial venda dentro do Chatwoot sem depender do Kommo, mantendo a conversa como ponto de trabalho e o Kanban como visão operacional do funil.

O produto deve ajudar o vendedor a responder rapidamente:

- quem é o lead;
- em que etapa está;
- quem é o responsável comercial;
- qual é o próximo passo;
- quando esse próximo passo vence;
- quais oportunidades estão atrasadas, esquecidas, ganhas ou perdidas.

## Nao Objetivos

- Criar um CRM completo dentro do Chatwoot.
- Copiar Kommo, Woofed, Pipedrive, HubSpot ou Salesforce integralmente.
- Criar módulos complexos de empresa, contrato, produto, faturamento ou proposta.
- Fixar o fluxo em consulta, reunião ou qualquer tipo específico de venda.
- Criar automações avançadas antes de validar o uso manual.
- Substituir o atendimento do Chatwoot por um CRM separado.
- Importar dados diretamente do Kommo. A migração será tratada fora do produto, se necessária.

## Principio Central

Toda oportunidade aberta precisa ter:

- contato;
- conversa de origem ou contexto comercial;
- etapa;
- responsável comercial;
- próximo passo;
- valor, quando o board usar venda com ticket ou orçamento.

O próximo passo deve ser configurável por funil. Consulta, reunião, proposta, cobrança, pagamento e follow-up são apenas tipos possíveis de próxima ação.

## Principios De Experiencia

O Kanban deve ser intuitivo para quem vende e interativo para quem configura.

Regras de UX:

- ações frequentes devem acontecer no contexto atual, sem obrigar o usuário a sair da conversa ou do card;
- arrastar um card ou campo deve produzir feedback imediato e deixar claro onde ele será colocado;
- configurações avançadas devem usar divulgação progressiva: primeiro o essencial, depois condições, fórmulas e JSON;
- a interface deve explicar o resultado da regra em linguagem natural antes de salvar;
- erros devem indicar o campo e a correção necessária, preservando tudo que já foi preenchido;
- operações destrutivas ou de grande impacto devem pedir confirmação e informar quantos registros serão afetados;
- estados de carregamento, vazio, sucesso, falha e ausência de permissão devem ser explícitos;
- desktop e mobile devem preservar as mesmas tarefas essenciais;
- nenhuma configuração comum deve exigir edição de JSON;
- o sistema deve favorecer prevenção, desfazer quando viável e recuperação quando desfazer não for possível.

## Modelo Conceitual

### Contact

Pessoa ou lead. Deve continuar sendo o registro principal da pessoa no Chatwoot.

Dados que pertencem à pessoa, como data de nascimento, consentimento de comunicação, idioma e fuso horário, não devem ser duplicados em cada oportunidade.

`date_of_birth` é um campo canônico do contato para o nosso produto. É provisionado como atributo personalizado de contato do Chatwoot, com tipo data, chave estável e presença garantida na ficha do contato. Ele não é campo do board.

### Conversation

Interação ou atendimento. Pode originar uma oportunidade, mas não deve ser tratada como a oportunidade em si.

Quando uma oportunidade abre a conversa de origem, a área `Oportunidades` do painel lateral mantém um atalho por card para reabri-lo no funil. O atalho é profundo: abre o board e o card específico, inclusive quando o contato possui várias oportunidades.

### KanbanCard

Oportunidade comercial. Representa a venda em andamento.

Um contato pode ter mais de uma conversa e mais de uma oportunidade. A conversa é canal/contexto; o card é a oportunidade.

### Board

Funil comercial configurável. Cada board define etapas, tipos de próximo passo, campos personalizados, motivos de perda e regras de alerta.

Um board pode representar uma unidade, operação ou time comercial. Administradores veem todos os boards; para agentes, cada board pode ser limitado a agentes selecionados e a caixas de entrada selecionadas. A API deve aplicar esse escopo, e não apenas esconder a navegação.

Para clínica com uma médica administradora e duas secretárias, a configuração recomendada é um board por unidade, com a secretária e o WhatsApp correspondentes selecionados no board. A médica mantém acesso aos dois funis.

### Stage

Etapa do funil. Deve representar avanço real na venda, não apenas uma atividade solta.

### Next Action

Próximo passo comercial. Deve ter data/hora, tipo, observação e status.

### Custom Fields

Campos personalizados por board para adaptar o card a diferentes operações.

Cada board pode configurar seu próprio conjunto de campos, sem afetar outros boards.

Tipos mínimos:

- texto;
- texto longo;
- seleção única;
- inteiro;
- decimal;
- moeda;
- data;
- data e hora;
- booleano;
- fórmula.

Cada campo deve permitir:

- chave estável;
- nome exibido;
- tipo;
- opções, quando aplicável;
- posição/layout no modal;
- visibilidade condicional baseada em outro campo;
- fórmula simples baseada em outros campos numéricos;
- obrigatoriedade por etapa.

Exemplo de condicional:

- campo `motivo_nao_fechou` aparece somente se `fechou` = `Não`.

Exemplo de fórmula:

- `valor_total = procedimento + exames`.

O layout dos campos é configurável por board por meio de abas, posição e largura. O administrador pode arrastar campos entre as abas e reordená-los dentro de cada aba.

As abas padrão são:

- `Geral`, com título, descrição, valor e campos comerciais gerais;
- `Marketing`, com origem, suborigem e atribuição de mídia.

Outras abas são criadas pelo botão `+` ao lado das abas padrão. A aba pertence ao board, possui nome e chave estável próprios e continua existindo mesmo quando ainda não contém campos.

### Experiencia De Configuracao Dos Campos

A configuração pertence ao funil, porque altera todas as oportunidades daquele board. O acesso, porém, deve ser contextual e fluido:

- a engrenagem no card abre diretamente o gerenciador de campos do funil;
- o botão `+` ao lado das abas abre o fluxo de criação de aba;
- o gerenciador mostra as abas em formato compacto e edita somente um campo por vez;
- abas são botões de navegação, sem inputs ou ações misturados nelas; renomear, reordenar e excluir aparecem somente na barra contextual da aba ativa;
- criar aba usa diálogo curto com nome, Cancelar e Criar; não expande o construtor;
- grupos da aba são administrados em diálogo contextual; o layout principal conserva apenas os blocos e as zonas para posicionar campos;
- criar campo abre um diálogo curto com nome e tipo e gera a chave estável automaticamente; opções, condição, fórmula e obrigatoriedade só aparecem depois, quando aplicáveis;
- opções de seleção são adicionadas em uma linha curta e exibidas como chips;
- etapas obrigatórias são escolhidas por uma grade compacta de checkboxes;
- campos podem ser arrastados entre abas e reordenados;
- o JSON permanece recolhido em uma área avançada e nunca é necessário no fluxo comum.

## Personalizacao

O Kanban precisa funcionar para vendas diferentes.

Exemplos:

- venda 100% via WhatsApp;
- clínica com consulta;
- serviço B2B com diagnóstico e proposta;
- cursos;
- estética;
- imobiliária;
- advocacia;
- consultoria;
- operações com fechamento direto sem reunião.

O sistema não deve impor "consulta", "reunião" ou "proposta". Ele deve permitir que cada board configure os nomes e tipos relevantes.

## Configuracao Comercial Por Board

Cada board deve permitir ao administrador configurar:

- tipos de próxima ação;
- motivos de perda;
- campos personalizados e campos visíveis no card compacto;
- limite de dias parado em cada etapa.

Alertas de oportunidade parada devem iniciar em formato resumido, mostrando quantas etapas possuem limite configurado. A lista de limites por etapa só é aberta ao escolher `Configurar`, preservando a leitura rápida das demais configurações comerciais.

O lembrete interno de agendamento é independente das automações de mensagem ao cliente. Ele cria apenas uma próxima ação e deve informar esse efeito no resumo; sua configuração de antecedência também permanece recolhida até `Configurar`.

As listas de tipos de próxima ação e motivos de perda fazem parte do MVP. Elas devem ser editáveis em configurações do board, com uma opção por linha, e o sistema deve ignorar opções vazias ou duplicadas.

Se o board ainda não tiver listas configuradas, o sistema deve usar listas padrão úteis para venda via WhatsApp.

## Automacoes Comerciais

As automações ficam em uma área própria do board, separadas da operação manual do card. O card mostra o resultado e o histórico, mas não esconde de onde veio uma ação ou mensagem.

### Construtor Visual De Automacoes

O detalhamento de produto está em [Kanban Visual Workflows PRD](kanban-visual-workflows-prd.md) e o contrato técnico em [Kanban Visual Workflows Spec](kanban-visual-workflows-spec.md).

O board oferece um construtor visual próprio baseado em Vue Flow. Ele é uma interface para regras comerciais do Chatwoot, não um editor genérico de código, integrações arbitrárias ou credenciais externas.

Nós disponíveis no construtor atual:

- `Gatilho`: usa um evento já publicado pela oportunidade, como criação, mudança de etapa, ganho, perda ou próxima ação concluída;
- `Aguardar`: pausa a execução por um número positivo de horas e a retoma por job, sem manter processo aberto;
- `Aguardar até data`, `Aguardar resposta` e `Aguardar horário comercial`: pausas comerciais persistidas, com prazo e fuso explícitos;
- `Condição`: caminhos Sim e Não sobre dados permitidos da oportunidade;
- `Enviar mensagem`: envia WhatsApp ou e-mail apenas para conversa compatível, com texto, emoji, variáveis, imagem, opt-in obrigatório e respeito à janela de 24 horas do WhatsApp;
- `Ação comercial`: criar próxima ação, mover etapa, arquivar, atribuir responsável, distribuir em rodízio, preencher/incrementar campo, etiqueta ou nota interna;
- `Webhook`: entrega HTTPS por conexão aprovada, assinada e auditável;
- `Fim`: encerra explicitamente o fluxo.

Cada fluxo é versionado como JSON validado pelo backend. Todo salvamento, atualização ou restauração gera um snapshot imutável; restaurar exige confirmação e cria uma nova versão, sem reescrever execuções já iniciadas. O canvas nunca executa código enviado pelo usuário. Execuções possuem chave idempotente por evento, estado persistido ao aguardar e histórico dos nós executados.

Fora do escopo atual ficam loops, código arbitrário, credenciais soltas no canvas, importação do N8N e integrações complexas. Esses itens só entram quando houver uma experiência de revisão, simulação e trilha de auditoria equivalente.

Estado atual: o board aceita regras por evento, condição e etapa; o scheduler cria entregas idempotentes por agendamento/canal; e o serviço de mensagens respeita opt-in, janela do WhatsApp, horário silencioso e limite de frequência. Cadências podem ser inscritas automaticamente ao entrar em uma etapa, mantendo os passos atuais como tarefas internas. A central também oferece teste sem efeito colateral, conexões de webhook, execuções, cancelamento/retry e histórico de versões por regra.

### Lembretes De Consulta

O lembrete de consulta deve ser iniciado por um evento de negócio explícito, preferencialmente a entrada da oportunidade em uma etapa como `Agendado`. O evento seleciona a regra, mas não substitui a data/hora da consulta: a regra também aponta para um campo `datetime` do card, por exemplo `data_hora_consulta`.

Essa combinação é a prática padrão do produto:

- **gatilho:** oportunidade entrou em `Agendado`;
- **fonte do horário:** campo `Data e hora da consulta`;
- **agenda:** offsets configuráveis, como `48h`, `24h` e `2h` antes;
- **reentrada:** uma execução por agendamento; reagendamento cria uma nova versão;
- **saída:** mensagem externa e/ou tarefa interna, conforme a regra.

O administrador pode adicionar outros gatilhos, como criação da oportunidade, alteração da data ou início manual. A etapa sozinha nunca deve disparar uma mensagem sem uma data válida.

O administrador configura o campo de data e hora, um ou mais offsets (`48h`, `24h`, `2h`), mensagem ou template por offset, canais permitidos e fuso horário. Condições opcionais podem limitar o envio por etapa, confirmação, status ou opt-in.

Comportamento obrigatório:

- cada offset envia no máximo uma vez para cada agendamento;
- alterar a data cancela lembretes pendentes e recria a programação;
- cancelar, perder ou arquivar a oportunidade interrompe lembretes futuros;
- sair de `Agendado`, trocar a data, remover o opt-in ou cancelar a consulta interrompe a versão pendente;
- ausência de conversa compatível registra o não envio, sem tentativas infinitas;
- WhatsApp fora da janela de 24 horas exige template aprovado;
- a tela mostra prévia, próximo envio e histórico de tentativas;
- o lembrete externo é separado da próxima ação interna do vendedor.

Preencher uma data não autoriza, por si só, uma mensagem externa. Opt-in, canal, horário silencioso e regras da conta devem ser respeitados.

### Cadencia De Follow-up

Cadência é uma sequência de passos temporizados aplicada a uma oportunidade. Ela deve substituir gradualmente fluxos simples hoje mantidos no N8N, com execução visível, pausável e cancelável.

Pode iniciar manualmente pelo card, ao entrar em uma etapa, quando a oportunidade é criada ou por uma regra comercial.

Cada passo declara espera, ação interna, mensagem externa opcional, condição e observação. Ações internas incluem criar próxima ação, atribuir responsável, mover etapa e adicionar etiqueta. Mensagens externas precisam declarar canal, template/texto, consentimento e limite de envio.

Paradas padrão: resposta do cliente, mudança de etapa, ganho, perda, arquivamento, remoção de opt-in ou cancelamento manual.

A primeira versão deve manter cadências internas sem mensagem ao cliente. Mensagens externas entram depois, com idempotência, janela do WhatsApp, templates aprovados, limite de frequência, horário silencioso e trilha de auditoria.

Exemplo de cadência de vendas via WhatsApp:

1. imediatamente: criar tarefa `Responder lead`;
2. após 24h sem resposta: criar tarefa `Cobrar retorno`;
3. após 48h sem resposta: enviar template aprovado, se houver consentimento;
4. após 72h sem resposta: mover para `Follow-up` e criar última tarefa;
5. parar em qualquer resposta, ganho, perda ou cancelamento.

## Pipeline

As etapas devem ser configuráveis.

Templates iniciais recomendados:

### Venda por WhatsApp

- Novo lead
- Em conversa
- Interesse identificado
- Proposta enviada
- Follow-up
- Fechado
- Perdido

### Clínica ou Consulta

- Novo lead
- Qualificado
- Consulta agendada
- Confirmado
- Compareceu
- Fechado
- Perdido

### Serviço B2B

- Novo lead
- Diagnóstico
- Proposta
- Negociação
- Contrato enviado
- Fechado
- Perdido

### Funil em Branco

O administrador cria as etapas do zero.

## Card Comercial

O card deve ser compacto, escaneável e orientado a ação.

Campos mínimos:

- nome do contato;
- canal/inbox;
- responsável comercial;
- etapa;
- valor da oportunidade, quando aplicável;
- última mensagem ou contexto curto;
- próximo passo;
- data/hora do próximo passo;
- status do próximo passo: futuro, hoje, atrasado, sem próximo passo;
- indicador de ganho/perda quando aplicável.

Campos opcionais:

- valor estimado;
- moeda;
- produto ou serviço de interesse;
- origem do lead;
- cidade/unidade;
- plano escolhido;
- temperatura do lead;
- observação comercial;
- campos personalizados definidos pelo board.

O campo de descrição/observação no modal deve ser útil para contexto, mas não pode dominar a tela. A descrição deve ser menor que a versão inicial do modal, deixando espaço para dados comerciais, próxima ação e fechamento.

## Valor Da Oportunidade

O Kanban deve ter campo nativo de valor no card.

Regras:

- valor é opcional por padrão;
- board pode tornar valor obrigatório em etapas específicas;
- moeda padrão inicial deve ser BRL;
- relatórios de ganho/perda devem conseguir somar valores quando preenchidos;
- valor não substitui campos personalizados de orçamento detalhado.

## Campos Personalizados E Layout

Campos personalizados são parte do produto comercial, não apenas detalhe técnico.

Cada board deve poder definir seus próprios campos, porque nem toda operação usa consulta, reunião ou proposta formal. Um cliente pode vender 100% via WhatsApp, outro pode precisar de consulta, outro pode fechar direto.

Tipos necessários:

- texto curto;
- texto longo;
- seleção única;
- seleção múltipla;
- inteiro;
- decimal;
- moeda/valor;
- data;
- data e hora;
- checkbox/sim ou não;
- fórmula;
- URL.

Cada campo deve ter:

- chave estável;
- nome exibido;
- tipo;
- opções, quando o tipo exigir;
- seção/layout no modal;
- posição;
- largura sugerida;
- visibilidade opcional no card compacto;
- obrigatoriedade opcional por etapa;
- condição de exibição opcional;
- fórmula opcional para campos calculados.

### Aba Marketing

O board oferece um preset idempotente de campos de marketing. Ao sincronizá-lo, o conjunto canônico substitui somente os campos conhecidos do preset, remove chaves obsoletas e preserva campos desconhecidos criados pelo cliente na aba Marketing.

O preset cobre exatamente:

- `Origem`, `Sub-origem`, `Campanha`, `Conjunto` e `Anuncio`;
- `utm_content`, `utm_medium`, `utm_campaign`, `utm_source`, `utm_term` e `utm_referrer`;
- `referrer`, `gclientid`, `gclid` e `fvclid`;
- `ttad_name`, `ttad_id`, `fbc`, `fbp` e `ttclid`;
- `campaign_id`, `adset_id`, `ad_id`, `landing_page`, `event_id` e `landing_page_full`.

As chaves são estáveis para permitir preenchimento por API e automações sem depender do texto exibido.

### Condicionais

O administrador deve poder configurar uma regra simples:

- se campo X for igual a valor Y, exibir campo Z.

Exemplo:

- se `consulta_realizada = Sim`, mostrar `valor_procedimento`;
- se `forma_pagamento = Parcelado`, mostrar `numero_parcelas`.

### Formulas

Campos do tipo fórmula devem calcular valores a partir de outros campos.

Exemplos:

- `valor_total = procedimento + exames`;
- `valor_total = entrada + parcelas`;
- `ticket_medio = valor_total / quantidade`.

Fórmulas devem ser simples e seguras no MVP: operações matemáticas básicas e referência ao valor da oportunidade, a campos inteiros, decimais, monetários e a campos calculados anteriores. Não deve existir execução arbitrária de código.

Na configuração de um campo:

- `Mostrar quando` e `For igual a` configuram somente uma condição de visibilidade;
- a expressão matemática é preenchida no editor `Fórmula`, visível somente quando o tipo do campo for `Fórmula`;
- a expressão contém apenas o cálculo, por exemplo `procedimento + exames`, sem escrever `valor_total =`;
- digitar `[` abre os campos numéricos e monetários compatíveis; o texto após `[` filtra por nome e a seleção entra como marcador legível, por exemplo `[Valor da oportunidade]`;
- a UI converte marcadores legíveis para chaves estáveis antes de salvar, valida a expressão e mantém o backend como autoridade do cálculo;
- constantes decimais aceitam ponto ou vírgula, portanto `0.2` e `0,2` são equivalentes;
- campos calculados podem referenciar apenas fórmulas anteriores na ordem do board, evitando referência futura e ciclos;
- o texto `For igual a` nunca deve ser usado para digitar fórmula.

Fórmulas com datas ficam fora deste MVP até existir um tipo de resultado explícito e semântica definida para soma de dias, diferença entre datas e data/hora. Campos de data continuam disponíveis como dados e condições, mas não aparecem como operandos matemáticos.

### Obrigatoriedade Por Etapa

Campos podem ser obrigatórios somente ao chegar em determinada etapa.

Exemplos:

- ao mover para `Proposta enviada`, exigir `valor`;
- ao mover para `Consulta agendada`, exigir `data_consulta`;
- ao mover para `Fechado`, exigir `valor_final`.

Se a etapa exige campo e ele não foi preenchido, o sistema deve bloquear o avanço e mostrar qual campo falta.

## Proxima Acao

O próximo passo é o coração do produto.

Campos:

- tipo;
- data/hora;
- observação;
- concluído em;
- criado por;
- atualizado por.

Tipos configuráveis por board.

Exemplos:

- chamar novamente;
- enviar proposta;
- enviar link de pagamento;
- cobrar retorno;
- confirmar pagamento;
- confirmar consulta;
- reagendar;
- enviar contrato;
- follow-up contrato;
- outro.

## Alertas

Alertas devem ser simples no MVP.

Estados:

- sem próximo passo;
- próximo passo hoje;
- próximo passo atrasado;
- card parado na etapa há X dias.

No MVP, alerta pode ser visual no card e via filtro. Notificação interna pode entrar em fase posterior.

## Filtros

Filtros mínimos:

- board;
- etapa;
- responsável;
- inbox;
- próximo passo hoje;
- próximos passos atrasados;
- sem próximo passo;
- ganho;
- perdido.

Filtros futuros:

- tipo de próximo passo;
- origem do lead;
- campos personalizados;
- valor;
- tempo parado na etapa.

Para concluir a estrutura do Kanban, também são necessários:

- busca por oportunidade, contato, telefone e assunto;
- combinação clara de filtros ativos com ação `Limpar filtros`;
- filtros salvos por usuário para rotinas recorrentes;
- ordenação por próxima ação, valor, criação e tempo na etapa.

## Ganho e Perda

Ao marcar como perdido, o sistema deve pedir motivo de perda.

Motivos configuráveis por board. No MVP, o vendedor deve escolher o motivo a partir da lista configurada no board, preservando o motivo já salvo mesmo que ele deixe de existir na lista.

Motivos iniciais sugeridos:

- sem resposta;
- preço;
- sem interesse;
- não compareceu;
- fora do perfil;
- fechou com outro;
- outro.

Ao marcar como ganho, o sistema deve registrar data e responsável pelo fechamento.

## Indicadores Compactos

O board exibe somente um resumo operacional compacto no topo:

- oportunidades abertas;
- oportunidades ganhas;
- oportunidades perdidas;
- oportunidades atrasadas;
- valor ganho.

Não existe painel expansível de relatório comercial nem agenda dentro do board. O trabalho diário continua apoiado pelos filtros de hoje, atrasados e sem próxima ação.

## Entrada No Atendimento E Contatos

O Kanban deve estar disponível como item próprio na navegação principal do Chatwoot, com ícone consistente com o sidebar atual.

Além disso, a experiência comercial precisa aparecer dentro do fluxo de atendimento:

- na conversa, o agente deve conseguir ver oportunidades vinculadas ao contato/conversa;
- na conversa, o agente deve conseguir criar oportunidade no Kanban sem sair do atendimento;
- no contato, deve existir uma visão/grupo Kanban com oportunidades daquele contato;
- se houver múltiplas oportunidades para o mesmo contato, elas devem aparecer separadas.

O Kanban continua sendo a visão de funil; conversa e contato continuam sendo pontos de entrada operacional.

## Fluxo Da Secretaria

Fluxo recomendado para venda por WhatsApp:

1. Cliente chama no WhatsApp e a conversa entra no Chatwoot.
2. Se o board estiver configurado para auto criação, a conversa elegível cria uma oportunidade na primeira etapa.
3. Se o board não estiver com auto criação, a secretária cria a oportunidade manualmente pela conversa ou contato.
4. Secretária qualifica o lead no atendimento e preenche campos mínimos: responsável comercial, valor quando existir, próxima ação e observação.
5. Secretária usa os filtros `Sem ação`, `Hoje` e `Atrasados` como agenda diária.
6. Quando houver avanço real, move o card de etapa.
7. Ao fechar, marca ganho ou perdido com motivo.

Auto criação deve ser configurável por board/inbox. Não deve criar cards automaticamente em todos os funis sem regra, para evitar bagunça operacional.

## Regras De Produto

- A conversa pode criar uma oportunidade, mas não deve ser a própria oportunidade.
- Um card aberto sem próximo passo deve ser considerado problema operacional.
- Etapas devem ser configuráveis por board.
- Tipos de próximo passo devem ser configuráveis por board.
- Motivos de perda devem ser configuráveis por board.
- Campos personalizados devem ser configuráveis por board.
- Campos personalizados devem suportar layout, condicionais, fórmulas e obrigatoriedade por etapa.
- Nenhum fluxo deve assumir que existe consulta ou reunião.
- O Kanban deve continuar integrado ao Chatwoot, sem exigir CRM externo.
- A criação automática de oportunidades deve ser configurável por board/inbox, não global.
- A criação manual deve continuar disponível mesmo quando a automação estiver ligada.

## Fronteira Com Automacoes

O Kanban não deve hospedar o construtor completo de automações dentro do board ou do card.

Responsabilidade do Kanban:

- manter oportunidades, etapas, responsáveis, datas e próximos passos confiáveis;
- publicar eventos de domínio, como card criado, etapa alterada, oportunidade ganha/perdida e próxima ação concluída;
- expor campos do card, contato e conversa como dados selecionáveis por regras;
- mostrar, no card, quais automações estão ativas e permitir interromper uma execução quando autorizado.

Responsabilidade de um módulo próprio de `Automações`:

- configurar gatilho, condições e ações;
- executar ações imediatamente ou em relação a uma data;
- criar tarefas e notificações;
- enviar mensagens aprovadas;
- controlar cadências, espera, pausa, retomada e saída;
- registrar execuções, erros, tentativas e cancelamentos.

Classificação dos casos levantados:

1. **Lembrete de agendamento:** o Kanban já pode criar uma próxima ação interna relativa a `starts_at`, configurada em horas por board. O envio de WhatsApp/email continua pertencendo ao módulo de automações e exige ativação explícita.
2. **Mensagem de aniversário:** automação recorrente anual baseada em `contact.date_of_birth`. Não depende de existir oportunidade no Kanban.
3. **Cadência de follow-up:** módulo de sequências/cadências, com passos de mensagem, espera e tarefa manual. O card pode inscrever ou retirar o contato da cadência, mas não deve ser o editor da sequência.

Uma cadência precisa parar ou pausar quando houver resposta do cliente, opt-out, oportunidade ganha/perdida, contato inválido ou intervenção manual configurada. Mensagens de WhatsApp devem respeitar consentimento, templates aprovados, janela de atendimento, fuso horário e limites de frequência.

## Fechamento Estrutural Do Kanban

## Experiencia De Trabalho Comercial

O Kanban terá duas visões complementares:

- `Kanban`, para acompanhar fluxo, capacidade e avanço por etapa;
- `Lista`, para buscar, comparar, selecionar e editar oportunidades com volume maior.

A visão em lista reutiliza os mesmos filtros, seleção em massa e abertura da oportunidade. O cabeçalho da tabela permite selecionar apenas as oportunidades visíveis e carregadas; ele não presume que páginas ainda não carregadas serão alteradas. Ela não cria um segundo modelo de dados.

### Cabeçalho Do Board

O quadro é a superfície principal de trabalho. O cabeçalho é operacional e curto, distribuído em duas linhas:

1. primeira linha: seletor de funil, busca, `Nova oportunidade` e menu de ações;
2. segunda linha: seletor Kanban/Lista, `Hoje` e abertura de filtros, com a contagem de critérios ativos no próprio botão.

Ordenação e filtros salvos ficam no popover de filtros. Exportação, métricas, automações, configurações e ações administrativas ficam no menu de ações. Filtros rápidos como sem ação, atrasadas e ganhos também pertencem ao popover, nunca a uma linha permanente. Métricas do funil são consultadas sob demanda e não competem com os cards.

Ordenar, salvar, renomear, excluir e limpar filtros também acontecem dentro desse painel. Ao iniciar uma dessas ações, o painel abre automaticamente e mantém a ação no mesmo contexto dos critérios que serão salvos. A busca tem `Enter`, uma ação visível de buscar e uma limpeza própria, que não altera os demais critérios ativos.

Esta composição segue o padrão funcional observado em CRMs como Attio e Twenty e no fluxo compacto de Linear: referência de comportamento e densidade, não cópia visual.

### Central De Atividades

`Próxima ação` é um dado da oportunidade, mas o trabalho diário precisa de uma visão própria, chamada `Hoje`. Ela abre como superfície independente do quadro e não como um bloco fixo no cabeçalho. A Central de Atividades deve oferecer:

- minhas atividades de hoje;
- atividades atrasadas;
- próximas atividades;
- oportunidades sem próxima ação;
- agrupamento por responsável.

Cada item deve abrir a oportunidade e preservar o contexto do funil. Relatórios comerciais continuam separados porque respondem a perguntas de resultado, enquanto atividades respondem a "o que preciso fazer agora?".

### Detalhe Da Oportunidade

Clicar no card abre o detalhe lateral real, sobre o board, sem recalcular ou estreitar as colunas. Fechar o painel devolve a pessoa exatamente ao mesmo ponto do funil. No desktop o drawer é estreito o bastante para preservar a leitura do quadro; no mobile ele ocupa a viewport com controles de retorno e foco previsível.

O drawer usa:

- cabeçalho fixo com título, contato, etapa, valor e responsável;
- abas Resumo, Atividades e Conversa;
- grupos de campos compactos, com edição contextual;
- conversa e linha do tempo sem abandonar a oportunidade;
- rodapé fixo com ações primárias.

Configuração de campos não deve ficar misturada à edição normal. A engrenagem abre o gerenciador do board em padrão lista/tabela e detalhe progressivo, enquanto a edição do card mostra somente dados da oportunidade. O administrador vê uma lista compacta de campos, abas e regras; abre o item necessário para editar, sem várias caixas grandes concorrendo pela mesma tela.

As etapas seguem o mesmo padrão: a lista mostra apenas ordem, cor, nome, quantidade e categoria. Clicar em uma etapa abre seu detalhe único com categoria, alerta de capacidade e probabilidade; criar uma etapa acontece em diálogo curto com nome e cor, sem expandir a tela inteira.

### Entradas De Criacao

Devem coexistir três entradas:

- criação rápida pelo botão `Nova oportunidade`, iniciando na primeira etapa aberta;
- criação a partir da conversa, preservando inbox, contato e conversa de origem;
- criação a partir do contato, permitindo várias oportunidades legítimas para a mesma pessoa.

A criação automática de todas as conversas continua opcional por board/inbox. O padrão recomendado para venda é criação manual ou por automação explícita, evitando poluir o funil com atendimentos que não são oportunidades.

### Estagios Inteligentes

Cada etapa possui categoria `aberta`, `ganha` ou `perdida`, critério de saída, campos obrigatórios por etapa e alerta opcional de permanência. Mover um card para uma etapa terminal deve registrar o fechamento e usar as mesmas validações do modal.

O sistema deve sugerir o próximo passo quando a etapa exigir uma ação, mas nunca impor consulta, reunião ou proposta. Limite de cards é alerta de capacidade, não bloqueio.

### Permissoes Comerciais

Permissões devem separar:

- visualizar board e oportunidades;
- criar oportunidades;
- editar dados e campos;
- mover etapa;
- ganhar/perder e reabrir;
- atribuir responsável;
- executar ações em massa;
- configurar campos, etapas e listas;
- arquivar/restaurar.

Administrador configura o board. Agente trabalha nas oportunidades permitidas. A API deve autorizar cada operação no backend, sem depender de esconder botões no frontend.

### Governanca De Dados

Campos, abas e grupos possuem chaves estáveis. Remover ou alterar um campo que já tem valores exige aviso com a quantidade de oportunidades afetadas e uma decisão explícita sobre preservar, limpar ou migrar os valores. Fechar configurações com alterações não salvas deve pedir confirmação.

O histórico comercial é imutável para auditoria. O sistema registra ator, horário, valor anterior, valor novo, etapa anterior e etapa nova. Dados de marketing mantêm o conjunto canônico de atribuição, sem recriar os campos legados removidos.

Antes de iniciar o módulo de automações, o Kanban precisa fechar estas lacunas, em ordem:

### Prioridade P0

- **Histórico completo da oportunidade:** linha do tempo de criação, mudanças de etapa, responsável, valor, campos, próximas ações e fechamento, com ator e horário.
- **Semântica das etapas:** categoria configurável `aberta`, `ganha` ou `perdida`; movimentar para etapa terminal deve usar o mesmo fluxo validado de fechamento.
- **Movimentação assistida:** ao arrastar para uma etapa com campos obrigatórios, abrir um formulário curto com os dados faltantes; se cancelar ou falhar, devolver visualmente o card à origem.
- **Busca e produtividade:** busca global no board, filtros ativos claros, limpar filtros, ordenação e filtros salvos.
- **Construtor de campos intuitivo:** separar dados básicos, condição e fórmula; usar selects e prévia em linguagem natural; esconder JSON na área avançada.
- **Qualidade de dados:** aviso compreensível para possível oportunidade duplicada, sem impedir múltiplas oportunidades legítimas do mesmo contato.
- **Confiabilidade e acessibilidade:** feedback de salvamento, estados de erro recuperáveis, navegação por teclado e comportamento responsivo do board e modal.

### Prioridade P1

- arquivar/restaurar boards e oportunidades sem apagar histórico;
- ações em massa com confirmação e resumo de impacto;
- data prevista de fechamento opcional;
- destaque de campos importantes, sem torná-los obrigatórios;
- limites de trabalho por etapa apenas como alerta de capacidade, nunca bloqueio rígido de entrada de leads.

### Estado Verificado Em 22/07/2026

- `Implementado`: linha do tempo comercial, categorias de etapa, movimentação assistida, busca por oportunidade/contato/telefone/email, ordenação, filtros ativos, limpar filtros, filtros salvos e aviso de duplicidade.
- `Implementado`: construtor visual com condições, fórmulas por `[` e chaves estáveis, opções compactas, obrigatoriedade por checkbox, abas persistentes e preset exato de Marketing.
- `Implementado no P1`: arquivar/restaurar oportunidades, data prevista de fechamento, campos importantes e alerta de capacidade por etapa.
- `Implementado`: ações em massa com confirmação, resumo de impacto, sucesso parcial e arquivamento/restauração; permissões comerciais são aplicadas por operação no backend.
- `Implementado`: `date_of_birth` provisionado por conta, automação anual de aniversário com opt-in, timezone, horário, canais WhatsApp/email e idempotência de entrega.
- `Preparado para aceite`: suíte Playwright real em desktop Chrome e Pixel 7 cobre foco, teclado, drawer, abas, nomes acessíveis e responsividade; leitor de tela ainda precisa ser executado com VoiceOver/NVDA em ambiente real.
- `Pendente de produção`: concorrência entre agentes, retries de jobs e carga elevada precisam ser executados no Swarm com dados representativos.
- `Pendente de acabamento`: renomear, reordenar e excluir abas personalizadas; renomear e excluir filtros salvos pela interface; mostrar uma prévia numérica da fórmula antes de salvar.
- `Futuro`: fórmulas com datas e horas dependem de semântica explícita para soma de dias, duração, diferença entre datas, resultado e fuso horário.

O módulo de automações segue separado do Kanban. O aniversário já possui uma primeira automação controlada; cadências, lembretes e demais notificações devem continuar obedecendo opt-in, janela, timezone, idempotência e auditoria.

### Fora Do Fechamento Atual

- previsão de receita por probabilidade;
- catálogo de produtos, propostas, contratos e faturamento;
- BI avançado;
- editor de automações e cadências.

## Entregue

O Kanban comercial entregue inclui:

- adicionar próximo passo no card;
- permitir tipos de próximo passo configuráveis por board;
- permitir motivos de perda configuráveis por board;
- permitir editar o responsável comercial da oportunidade;
- destacar cards sem próximo passo;
- destacar cards com próximo passo hoje;
- destacar cards atrasados;
- filtrar por hoje, atrasados e sem próximo passo;
- adicionar motivo de perda;
- registrar ganho/perda;
- adicionar valor da oportunidade;
- melhorar card compacto para venda;
- manter abertura rápida da conversa;
- campos personalizados por board;
- layout configurável de campos;
- campos condicionais;
- fórmulas simples;
- obrigatoriedade por etapa;
- escolher campos visíveis no card compacto;
- visão Kanban dentro de conversa e contato;
- indicadores compactos de abertas, ganhas, perdidas, atrasadas e valor ganho;
- templates de board;
- regras simples de alerta por etapa;
- histórico das próximas ações concluídas;
- abas Geral e Marketing no card;
- editor visual para arrastar e ordenar campos entre abas;
- preset completo de campos de atribuição de marketing.
- atributo padrão `date_of_birth` provisionado por conta;
- automação de aniversário com opt-in, timezone, horário configurável e entrega idempotente por WhatsApp/email;
- permissões comerciais separadas para visualizar, editar, mover, configurar, administrar e consultar relatórios;
- suíte Playwright opt-in para desktop Chrome, Pixel 7, teclado, foco, drawer e semântica ARIA.

## Proximas Fases

1. concluir os itens P0 de fechamento estrutural;
2. validar o fluxo manual completo com secretária e vendedor;
3. executar a suíte Playwright em desktop e mobile e validar VoiceOver/NVDA;
4. executar smoke, concorrência e alto volume no Swarm;
5. especificar o módulo próprio de automações;
6. validar em produção os lembretes internos de agendamento;
7. entregar cadências de follow-up;
8. evoluir automações recorrentes além do aniversário.

## Riscos

- Virar CRM completo demais.
- Misturar suporte com venda.
- Tratar conversa como lead e perder histórico comercial.
- Criar etapas demais.
- Criar automações antes de validar processo manual.
- Deixar cards sem próximo passo.
- Custom fields virarem bagunça sem governança.

## Decisoes De Produto

- O Kanban é comercial, não atendimento.
- O contato é a pessoa/lead.
- A conversa é canal/contexto.
- O card é oportunidade.
- A próxima ação é obrigatória para oportunidade aberta.
- Consulta é apenas um tipo configurável de próxima ação.
- O produto deve ser útil para venda 100% WhatsApp.
- Lembretes, aniversários e cadências usam dados do Kanban, mas pertencem a um módulo próprio de automações.
- O lembrete interno de agendamento é uma exceção operacional do Kanban: ele apenas cria uma próxima ação e nunca envia mensagem.
- Data de nascimento pertence ao contato, não à oportunidade.
- `For igual a` é condição; fórmula possui editor próprio.

## Referencias De Produto

- [Pipedrive: campos personalizados e regras de qualidade](https://support.pipedrive.com/en/article/custom-fields)
- [Pipedrive: campos obrigatórios por pipeline e etapa](https://support.pipedrive.com/en/article/required-fields)
- [Kommo: gatilhos do pipeline digital](https://support.kommo.com/docs/set-up-digital-pipeline-triggers)
- [HubSpot: criação e edição de sequências](https://knowledge.hubspot.com/sequences/create-and-edit-sequences)
- [monday CRM: sequências](https://support.monday.com/hc/en-us/articles/20666311273874-Sequences)
- [Atlassian: limites de trabalho em progresso no Kanban](https://www.atlassian.com/agile/kanban/wip-limits)
- [Chatwoot: atributos personalizados de contato](https://www.chatwoot.com/hc/user-guide/articles/1677502327-how-to-create-and-use-custom-attributes)
- [WhatsApp Business Messaging Policy](https://business.whatsapp.com/policy)
