# Propostas de Evolução de Experiência Raevo CRM

Data: 28 de agosto de 2026
Relacionada à [auditoria de experiência](./raevo-crm-experience-audit-2026-08-28.md)

## Princípios comuns

- Marca Raevo: `Pedra #E9E4DA`, `Areia #DCCFBE`, `Taupe #B8AB98`, `Carvão #1F1F1F`, `Champagne #C7A97A`, `Caian #00B8C6`; Sora para títulos e Inter para conteúdo.
- Desktop primeiro: alta densidade, hierarquia silenciosa, movimento somente para confirmar estado e transição (150-250ms).
- O dado é o foco, não o contorno. Uma superfície por contexto; cards apenas para itens repetidos, modal/drawer e ferramentas de configuração.
- Operação, configuração e análise ficam em lugares diferentes.
- Todo gesto por mouse possui alternativa por teclado; nenhum nome de entidade perde significado por truncamento.

## Proposta 1 - Mesa Comercial

### Ideia

Uma bancada de trabalho para secretaria e comercial. O quadro ou a lista domina a largura; o detalhe abre como drawer lateral fechável. É a proposta mais equilibrada entre venda, consulta e cobrança.

### Estrutura

- Navegação: `Conversas`, `Oportunidades`, `Hoje`, `Agenda`, `Financeiro`, `Formulários`.
- Cabeçalho operacional: seletor de funil, busca, `Filtros`, Kanban/Lista e `Nova oportunidade`.
- Kanban: colunas de 300px, card 104px, cabeçalho de etapa com contador, valor total e alerta de cards parados.
- Drawer: 600px, cabeçalho com título editável, funil/etapa, responsável, etiquetas e conversa. Aba `Resumo` mostra agora/próxima ação, valor e previsão; abas de domínio mantêm Agenda, Financeiro, Formulários, Contato e Histórico.
- Campos: rótulo discreto dentro do controle, uma linha por campo. Seções criadas pelo cliente aparecem como abas; grupos internos são divisores compactos recolhíveis. Campos obrigatórios e importantes recebem estado, não caixas maiores.
- Agenda: dia/semana em tela inteira; filtros sob um único botão `Agenda`; detalhe lateral e não modal central.
- Financeiro: lista operacional como padrão; resumo por status em uma faixa; configurações abre rota própria `Financeiro > Configurações`.

### Jornada

1. A secretaria atende em Conversas e abre/associa oportunidade no painel contextual.
2. Em Oportunidades, registra próxima ação, etapa e campos sem sair do quadro.
3. Em Agenda, cria/remarca consulta e volta ao drawer da oportunidade por contexto.
4. Em Financeiro, cria cobrança e prepara a mensagem no composer da conversa.
5. `Hoje` reúne atrasadas, consultas e cobranças pendentes como lista priorizada.

### Vantagens

- Melhor para o fluxo real Chatwoot + CRM.
- Reduz troca de tela e mantém a conversa acessível.
- Escala bem para campos customizados e módulos futuros.

### Riscos e mitigação

- Drawer pode ficar carregado: manter apenas seis abas de sistema, grupos recolhíveis e resumo com no máximo cinco informações.
- Kanban pode ser insuficiente para alto volume: visão Lista é cidadã de primeira classe e compartilha filtros.

### Recomendação

**Escolha recomendada.** É o melhor caminho para apresentação clínica e operação comercial diária.

## Proposta 2 - Central Clínica

### Ideia

Uma experiência centrada em paciente e agenda. O CRM se adapta à rotina de clínica, dando prioridade a consulta, confirmação, presença e plano de sessões.

### Estrutura

- Página inicial: `Hoje` como agenda operacional, com blocos compactos para Chegadas, Em atendimento, Atrasadas e Cobranças.
- Agenda é a área principal; agenda por profissional e procedimento, timeline diária e sem painéis de configuração visíveis.
- Oportunidade é um prontuário comercial lateral: `Paciente`, `Plano`, `Consulta`, `Financeiro`, `Histórico`.
- Kanban permanece para captação e vendas, com etapas clínicas menos visuais e cards menores.
- Formulários aparecem como “Pré-consulta” no detalhe do paciente, com alerta de pendência e leitura protegida.

### Jornada

1. A secretaria inicia pelo calendário e abre um paciente em drawer.
2. Confirma presença, rearranja sessão, envia lembrete ou cobrança.
3. O comercial usa Kanban somente antes/depois do ciclo clínico.
4. O médico recebe resumo da conversa e anamnese na consulta, preservando controle de dados sensíveis.

### Vantagens

- Muito forte para clínica com recorrência e volume de consultas.
- Coloca o agendamento no centro da rotina da secretaria.
- Facilita explicação em demonstração para médicos.

### Riscos e mitigação

- Pode parecer estreito para clientes B2B ou venda 100% WhatsApp: disponibilizar a proposta apenas por template de conta `Clínica`.
- Financeiro pode virar um anexo: manter a ação de cobrança dentro do drawer de paciente/consulta.

### Indicação

Clientes de saúde com agenda intensa, múltiplas sessões e rotina administrativa baseada em comparecimento.

## Proposta 3 - Console de Receita

### Ideia

Uma experiência de CRM de alta densidade inspirada em listas comerciais: busca, tabela, filtros salvos e ações em massa são a porta principal. O Kanban fica como uma visualização complementar.

### Estrutura

- Página `Oportunidades` abre na Lista, com colunas escolhidas pelo cliente: contato, etapa, responsável, próxima ação, valor, consulta, status de pagamento e campos importantes.
- Detalhe lateral persistente, sem trocar rota.
- Kanban é uma aba de visualização, útil para ritos de gestão e movimentação rápida.
- `Hoje` é uma fila de trabalho de ações com filtros pessoais/equipe.
- Agenda e Financeiro usam tabelas densas com mini-resumo e filtros em comando lateral.

### Jornada

1. A secretaria filtra “minhas próximas ações” e trabalha linha a linha.
2. Abre o detalhe, responde, agenda ou cobra sem abandonar a lista.
3. Gestor alterna para Kanban e relatórios para revisar o funil.

### Vantagens

- Melhor para alto volume, busca e ações em massa.
- Evita a lentidão cognitiva do Kanban com muitos cartões.
- Bom para operação com metas e equipe comercial.

### Riscos e mitigação

- Menos acolhedor e visual para clínica no primeiro contato.
- Requer bom configurador de colunas; começar com templates de lista por perfil.

### Indicação

Times comerciais com mais de quatro pessoas, alta quantidade de oportunidades e rotina forte de acompanhamento.

## Sequência de implementação recomendada

1. Aplicar a **Proposta 1** ao Kanban e ao drawer de oportunidade.
2. Reorganizar Agenda em trabalho versus configurações; criar `Hoje` clínico reutilizando a mesma base de dados.
3. Separar Financeiro operacional de configurações e integrar cobrança à oportunidade/conversa.
4. Evoluir Formulários para catálogo, editor por etapas e central de respostas.
5. Disponibilizar templates de navegação por conta: Comercial, Clínica e Console de Receita.

## Decisões que não devem ser adiadas

- `Hoje` é uma visão própria, não um painel dentro do Kanban.
- Configurar campos, procedimentos, provedores e formulários não acontece no detalhe da oportunidade.
- O detalhe da oportunidade é lateral por padrão; modal amplo somente para tarefas complexas de configuração.
- Busca e filtros são controles diferentes.
- A tela inicial de cada módulo mostra trabalho pendente, não configuração técnica.
