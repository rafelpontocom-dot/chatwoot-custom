# PRD: Kanban Comercial no Chatwoot

Status: fonte de verdade do produto

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

## Principio Central

Toda oportunidade aberta precisa ter:

- contato;
- conversa de origem ou contexto comercial;
- etapa;
- responsável comercial;
- próximo passo;
- valor, quando o board usar venda com ticket ou orçamento.

O próximo passo deve ser configurável por funil. Consulta, reunião, proposta, cobrança, pagamento e follow-up são apenas tipos possíveis de próxima ação.

## Modelo Conceitual

### Contact

Pessoa ou lead. Deve continuar sendo o registro principal da pessoa no Chatwoot.

### Conversation

Interação ou atendimento. Pode originar uma oportunidade, mas não deve ser tratada como a oportunidade em si.

### KanbanCard

Oportunidade comercial. Representa a venda em andamento.

Um contato pode ter mais de uma conversa e, no futuro, pode ter mais de uma oportunidade. A conversa é canal/contexto; o card é a oportunidade.

### Board

Funil comercial configurável. Cada board define etapas, tipos de próximo passo, campos personalizados, motivos de perda e regras de alerta.

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

O layout dos campos deve ser configurável por board. No MVP, layout pode ser simples: seção, posição e largura. No futuro pode virar editor visual com arrastar e soltar.

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
- futuramente, campos personalizados e campos visíveis no card compacto.

As listas de tipos de próxima ação e motivos de perda fazem parte do MVP. Elas devem ser editáveis em configurações do board, com uma opção por linha, e o sistema deve ignorar opções vazias ou duplicadas.

Se o board ainda não tiver listas configuradas, o sistema deve usar listas padrão úteis para venda via WhatsApp.

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
- URL, em fase posterior.

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

Fórmulas devem ser simples e seguras no MVP: operações matemáticas básicas e referência a outros campos numéricos. Não deve existir execução arbitrária de código.

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

## Relatorios MVP

Sem BI complexo no começo.

Métricas iniciais:

- oportunidades por etapa;
- oportunidades atrasadas por responsável;
- oportunidades sem próximo passo;
- ganhos;
- perdidos;
- valor ganho;
- valor em aberto;
- valor perdido;
- motivos de perda;
- ganhos/perdidos por responsável;
- ganhos/perdidos por etapa;
- taxa de comparecimento, se o board usar consulta;
- cards parados por etapa.

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

## MVP

Primeira versão após estabilizar o Kanban atual:

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
- manter abertura rápida da conversa.

## Fase 2

- campos personalizados por board;
- layout configurável de campos;
- campos condicionais;
- fórmulas simples;
- obrigatoriedade por etapa;
- escolher campos visíveis no card compacto;
- visão Kanban dentro de conversa e contato;
- relatórios simples de vendas por valor, etapa e responsável;
- templates de board;
- regras simples de alerta por etapa;
- histórico/timeline comercial no card.

## Fase 3

- notificações internas;
- nota privada automática no Chatwoot;
- automações leves por mudança de etapa;
- mensagens automáticas opcionais e controladas;
- relatórios avançados.

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
