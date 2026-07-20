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
- quem é o responsável;
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
- responsável;
- próximo passo.

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
- responsável;
- etapa;
- última mensagem ou contexto curto;
- próximo passo;
- data/hora do próximo passo;
- status do próximo passo: futuro, hoje, atrasado, sem próximo passo;
- indicador de ganho/perda quando aplicável.

Campos opcionais:

- valor estimado;
- produto ou serviço de interesse;
- origem do lead;
- cidade/unidade;
- plano escolhido;
- temperatura do lead;
- observação comercial;
- campos personalizados definidos pelo board.

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

Motivos configuráveis por board.

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
- motivos de perda;
- taxa de comparecimento, se o board usar consulta;
- cards parados por etapa.

## Regras De Produto

- A conversa pode criar uma oportunidade, mas não deve ser a própria oportunidade.
- Um card aberto sem próximo passo deve ser considerado problema operacional.
- Etapas devem ser configuráveis por board.
- Tipos de próximo passo devem ser configuráveis por board.
- Motivos de perda devem ser configuráveis por board.
- Campos personalizados devem ser configuráveis por board, mas não são obrigatórios no MVP.
- Nenhum fluxo deve assumir que existe consulta ou reunião.
- O Kanban deve continuar integrado ao Chatwoot, sem exigir CRM externo.

## MVP

Primeira versão após estabilizar o Kanban atual:

- adicionar próximo passo no card;
- permitir tipos de próximo passo configuráveis por board;
- destacar cards sem próximo passo;
- destacar cards com próximo passo hoje;
- destacar cards atrasados;
- filtrar por hoje, atrasados e sem próximo passo;
- adicionar motivo de perda;
- registrar ganho/perda;
- melhorar card compacto para venda;
- manter abertura rápida da conversa.

## Fase 2

- campos personalizados por board;
- escolher campos visíveis no card compacto;
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
