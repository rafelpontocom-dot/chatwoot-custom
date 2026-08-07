# PRD: Agenda Operacional do RAEVO CRM

Status: P0 em implementacao. A aba principal `Agenda`, o catalogo inicial de procedimentos/recursos, a reserva com bloqueio transacional de conflito, a recorrencia basica, os estados operacionais e o reagendamento ou cancelamento com escopo de serie estao implementados localmente. A configuracao por funil escolhe ativacao, etapas e procedimentos; recursos tambem podem receber janelas semanais, bloqueios e horarios especiais por data. O compositor e o reagendamento consultam horarios livres respeitando essas regras. A grade amplia sua escala quando existem consultas fora do horario comercial padrao. Ao mover uma oportunidade para uma etapa configurada, o drawer abre para sugerir o agendamento; a consulta tambem retorna ao card vinculado no funil. Integracoes seguem pendentes.

Produto relacionado: [Kanban Comercial](./kanban-sales-prd.md)

## Tese

A agenda nao e um campo `data_consulta` da oportunidade nem uma copia do Google Calendar.

Ela e o modulo operacional que transforma uma oportunidade em atendimento marcado, permite executar uma serie de sessoes, mantem o historico de cada ocorrencia e alimenta os lembretes comerciais ja existentes. O Kanban continua sendo a visao de venda; a agenda passa a ser a visao de tempo, capacidade e atendimento.

## Problema

Hoje a secretaria alterna entre Chatwoot, Kommo, N8N, calendario externo e sistema clinico. Para um plano de dez sessoes, a solucao baseada em campos da oportunidade obriga criar e preencher "Sessao 1", "Sessao 2" e assim por diante. Isso nao permite visualizar capacidade, remarcar somente uma sessao, cancelar o restante ou medir faltas com seguranca.

O resultado e trabalho manual, dados duplicados e lembretes que ficam desatualizados quando a data muda.

## Objetivos

- Marcar, confirmar, remarcar, cancelar e concluir consultas no RAEVO CRM.
- Permitir procedimentos configuraveis com duracao, intervalo, recursos e limite de recorrencia.
- Criar uma serie de sessoes para planos de acompanhamento, sem criar campos por sessao no card.
- Exibir agenda de dia e semana, inspirada na leitura do Google Calendar, sem copiar sua interface.
- Permitir abrir a marcacao diretamente da conversa, oportunidade, contato ou etapa do funil.
- Publicar eventos confiaveis para lembretes, automacoes e futura sincronizacao com Google Calendar, Cal.com, FEEGOW ou N8N.

## Nao Objetivos Do MVP

- Prontuario, evolucao clinica, faturamento, guia de convenio ou prontuario medico.
- Portal publico de autoagendamento.
- Sincronizacao bidirecional com Google Calendar, Cal.com ou FEEGOW.
- Disponibilidade calculada a partir de calendarios externos.
- Substituir o sistema clinico quando ele for a fonte legal de atendimento.
- Assumir que todo board tem consulta, medico ou recorrencia.

## Principios De Produto

1. **Uma consulta e uma ocorrencia.** Cada horario ocupado possui inicio, fim, status, profissional/recurso, contato e historico proprio.
2. **Uma serie nao e uma lista de campos.** Um plano de acompanhamento cria ocorrencias relacionadas e editaveis individualmente.
3. **O RAEVO e a fonte de verdade do MVP.** Integracoes externas recebem ids e eventos nossos; nunca substituem silenciosamente a serie local.
4. **Entrar em Agendado convida ao agendamento, nao agenda no escuro.** A etapa abre o compositor com dados sugeridos. Apenas uma confirmacao explicita cria a ocorrencia.
5. **Reagendar preserva historia.** A ocorrencia anterior e auditada; lembretes pendentes sao cancelados e recriados contra a nova versao.
6. **A agenda nao expande o CRM para clinica rigida.** "Consulta" e um tipo de procedimento. Um board pode chamar de visita, sessao, demonstracao ou retorno.
7. **Privacidade por padrao.** Titulos externos nao incluem diagnostico, observacoes internas nem valores comerciais.

## Usuarios E Fluxos

### Secretaria: marcar a primeira consulta

1. A secretaria esta na conversa ou na oportunidade.
2. Clica em `Agendar` na area Oportunidades ou move o card para uma etapa configurada como `Agendado`.
3. O compositor abre com contato, oportunidade, responsavel e procedimento sugeridos.
4. Seleciona procedimento, profissional/unidade, data e horario.
5. A tela mostra conflitos, duracao, intervalo de preparo e proximo horario livre.
6. Confirma. A oportunidade passa para a etapa definida pelo procedimento ou permanece na etapa atual, conforme configuracao do board.

Quando o card ja estiver em uma etapa configurada como `pede agendamento`, o painel da oportunidade mostra esse contexto e mantem o atalho `Agendar` visivel. A etapa convida a acao; ela nunca cria horario automaticamente.

### Secretaria: plano de acompanhamento

1. Escolhe um procedimento configurado como recorrente, por exemplo `Sessao de acompanhamento`.
2. Define quantidade, frequencia, primeiro horario e recurso.
3. Ve a previa de todas as sessoes antes de salvar.
4. Confirma a serie. Cada sessao vira uma ocorrencia independente ligada a uma serie.
5. Pode remarcar, cancelar ou marcar falta em uma ocorrencia sem destruir as demais.

### Secretaria: reagendamento ou cancelamento

- `Reagendar`: abre horario atual, recurso e alternativas livres. Ao confirmar, atualiza somente a ocorrencia escolhida ou permite escolher `esta e as proximas` quando for serie.
- `Cancelar`: exige motivo configuravel; oferece cancelar somente esta, futuras ou toda a serie.
- `Falta`: preserva o horario como `no_show`; nao e cancelamento e deve aparecer em relatorios futuros.
- `Concluir`: marca atendimento realizado; nao fecha a oportunidade automaticamente sem regra comercial explicita.

### Gestor: configurar operacao

- Cria procedimentos, duracao, buffers, recorrencia maxima, unidade, profissionais e politicas de etapa.
- Define horarios de trabalho e excecoes de cada recurso.
- Escolhe quem visualiza ou agenda cada calendario.
- Configura lembretes e automacoes no editor visual, usando eventos reais de agendamento.

## Experiencia Da Agenda

### Navegacao

Nova area principal `Agenda`, com acesso direto na navegacao lateral do CRM, logo apos `Kanban`. Nao fica escondida em relatorios ou em uma configuracao do board.

Cabecalho operacional:

- seletor de data com Hoje, anterior e proximo;
- visoes Dia e Semana no P0; Mes no P1;
- seletor de unidade/recurso;
- busca por contato, telefone ou oportunidade;
- botao `Novo agendamento`;
- botao de configuracao somente para quem tem permissao.

O calendario ocupa a tela inteira. A leitura e semelhante ao Google Calendar: escala de horas na esquerda, colunas por dia e, quando selecionado, faixas por profissional ou sala. O detalhe abre em drawer lateral; nao troca de pagina e nao cobre a grade permanentemente.

### Cartao De Agendamento

Mostra somente:

- horario e duracao;
- contato;
- procedimento;
- profissional/recurso;
- status com texto e icone, nunca apenas cor;
- sinal de recorrencia quando pertence a uma serie.

Descricao clinica, observacoes internas, origem da conversa e campos comerciais ficam no drawer.

### Compositor

O compositor e um drawer de duas colunas no desktop:

- esquerda: contato, oportunidade, procedimento, profissional, unidade e observacoes;
- direita: dia, faixa de horario, conflitos e alternativas livres.

Para serie, uma terceira etapa curta mostra a previa das ocorrencias e as excecoes antes da confirmacao. Ninguem precisa preencher uma linha para cada sessao.

O campo `Data e hora da proxima consulta` deixa de ser a fonte primaria quando existir ocorrencia de agenda. Ele pode receber espelhamento configuravel para compatibilidade com automacoes antigas, mas nao deve gerar duas fontes de verdade.

## Configuracao P0

### Procedimento

Cada procedimento pertence a uma conta e pode ser associado a boards.

- nome e cor;
- duracao padrao e buffers antes/depois;
- modalidade presencial, online ou telefone;
- unidade/local;
- recursos elegiveis: profissional, sala, equipamento ou agenda generica;
- permite recorrencia;
- maximo de ocorrencias da serie;
- frequencias permitidas: semanal, quinzenal, mensal e personalizada em dias;
- etapa sugerida apos marcar, cancelar, concluir ou faltar;
- politica de lembrete e consentimento aplicavel.

### Modulo Agenda No Funil

Cada board pode habilitar o modulo `Agenda` sem transformar uma data em campo comercial. A configuracao escolhe etapas que sugerem agendamento, procedimentos permitidos e, apenas quando necessario para automacoes legadas, um campo para espelhar a proxima ocorrencia. O card mostra um resumo de leitura e um atalho `Agendar`; recorrencia, sessoes e datas permanecem na agenda.

### Recurso E Disponibilidade

Um recurso e qualquer capacidade que nao pode ter conflito: profissional, sala, equipamento ou fila generica.

- nome, tipo, fuso e ativo;
- horarios semanais;
- excecoes por data, feriado ou bloqueio;
- procedimentos permitidos;
- permissao de visualizacao e edicao;
- capacidade inicial de um por horario. Capacidade maior entra somente quando houver caso real.

### Serie

Uma serie representa o plano comercial ou assistencial e nao precisa carregar informacao clinica sensivel.

- procedimento e contato;
- oportunidade opcional, mas recomendada quando nasceu de venda;
- quantidade contratada, quantidade agendada, concluidas, canceladas e faltas;
- frequencia, primeira ocorrencia e proxima ocorrencia;
- status ativa, concluida, cancelada;
- politica de alteracao: somente esta, esta e futuras, todas.

## Regras De Negocio P0

- Inicio deve ser anterior ao fim, em fuso IANA explicito.
- O horario so pode ser confirmado depois da verificacao transacional de conflito nos recursos exigidos.
- Drag-and-drop pode sugerir reagendamento, mas a confirmacao apresenta data, horario, impacto em lembretes e conflitos antes de gravar.
- Uma ocorrencia cancelada, concluida ou `no_show` nunca e apagada fisicamente.
- Remarcar incrementa uma versao da ocorrencia; lembretes pendentes da versao anterior sao cancelados.
- Uma serie gera ocorrencias individualmente. Editar uma excecao nao reescreve as demais.
- `esta e futuras` cria nova configuracao de serie a partir da ocorrencia escolhida e preserva as anteriores como historia.
- O limite de recorrencia e configuravel por procedimento. O produto nao adota o limite de 32 do Cal.com como restricao propria.
- A agenda nao altera etapa de oportunidade sem politica configurada; a politica precisa aparecer na confirmacao.
- Uma oportunidade pode ter varias series e varios agendamentos simultaneos.

## Automacoes E Mensagens

Os lembretes existentes devem migrar gradualmente de `field_key` para a ocorrencia de agenda. Eventos P0:

- `kanban.appointment.created`;
- `kanban.appointment.rescheduled`;
- `kanban.appointment.canceled`;
- `kanban.appointment.confirmed`;
- `kanban.appointment.completed`;
- `kanban.appointment.no_show`;
- `kanban.appointment.series_created`;
- `kanban.appointment.series_completed`.

Os eventos de ocorrencia ja sao publicados quando a agenda esta vinculada a uma oportunidade. Cada evento e idempotente por ocorrencia, tipo e versao; um reagendamento publica `rescheduled` sem disparar uma segunda criacao para a mesma troca de horario.

No editor visual, o no `Aguardar ate data` pode usar diretamente a data da ocorrencia que iniciou a automacao. Isso permite lembretes como `-24h` ou `-48h` sem espelhar a data em um campo comercial.

O editor visual pode iniciar por esses eventos e usar `Aguardar ate data` contra `appointment.starts_at`. O envio ainda respeita opt-in, janela de WhatsApp, template aprovado, horario silencioso e idempotencia. Cancelamento ou reagendamento precisa encerrar automaticamente entregas pendentes da versao anterior.

## Integracoes Futuras

### Direcao Aprovada

1. A agenda nativa do RAEVO CRM e a fonte de verdade do P0.
2. A primeira integracao externa sera exportacao unidirecional para Google Calendar por profissional/recurso.
3. Cal.com entra somente como canal opcional de autoagendamento; ele nao passa a possuir a agenda comercial nem as series de atendimento.
4. FEEGOW e N8N entram por eventos de dominio e conexoes aprovadas, nunca por acesso direto e arbitrario ao banco da agenda.

### Google Calendar: P1/P2

P1 oferece conexao OAuth por recurso e exportacao unidirecional dos agendamentos RAEVO. P2 habilita sincronizacao bidirecional somente depois de existir:

- mapeamento persistente entre ocorrencia e `calendarId/eventId` externo;
- sincronizacao inicial e incremental por `syncToken`;
- politica de conflito, exclusao e edicao concorrente;
- tela de diagnostico e reprocessamento;
- regra explicita de privacidade do titulo e convidados externos.

### Cal.com, FEEGOW E N8N: Futuro

Entram por conexoes aprovadas e eventos do dominio. Nao entram como chamadas HTTP livres no canvas. Cal.com pode servir como canal de autoagendamento; FEEGOW pode ser fonte clinica quando necessario; N8N permanece para orquestracoes maiores e legadas.

## Metricas Futuras

- taxa de comparecimento, falta, cancelamento e reagendamento;
- tempo entre venda e primeira consulta;
- ocupacao por recurso e procedimento;
- sessoes contratadas, marcadas e concluidas por serie;
- conversao de oportunidade agendada para ganha.

## Criterios De Aceite P0

1. Secretaria cria uma consulta unica pela conversa, oportunidade e pagina Agenda.
2. Secretaria cria uma serie de dez sessoes e visualiza todas antes de confirmar.
3. Sistema bloqueia conflito do mesmo profissional/sala, inclusive sob duas confirmacoes concorrentes.
4. Secretaria remarca uma sessao sem alterar as demais; pode tambem aplicar a mudanca a futuras sessoes.
5. Secretaria cancela uma, futuras ou todas as sessoes com motivo e auditoria.
6. Agenda mostra dia e semana com filtro por recurso, busca e drawer de detalhe.
7. Lembretes futuros sao cancelados e recriados no reagendamento; nenhum lembrete sai depois de cancelamento.
8. Nenhuma informacao clinica sensivel e publicada em titulo, webhook ou calendario externo por padrao.
9. Board sem configuracao clinica continua funcionando sem exibir obrigatoriedade de agenda.

## Decisoes Que Exigem Confirmacao Antes Da Implementacao

- nomes iniciais de procedimentos, unidades e recursos para o primeiro cliente;
- qual etapa deve abrir o compositor e quais etapas devem ser sugeridas apos marcar/cancelar/concluir;
- quais motivos de cancelamento e falta devem existir;
- politica para credito de sessao quando houver cancelamento ou falta;
- se o contato recebe confirmacao manual, automatica ou nenhuma no MVP.

## Referencias

- [Cal.com: tipos de evento e recorrencia](https://cal.com/docs/atoms/event-type)
- [Cal.com: recorrencias e limite atual](https://cal.com/help/event-types/recurring-events)
- [Google Calendar: eventos recorrentes](https://developers.google.com/workspace/calendar/api/guides/recurringevents)
- [Google Calendar: sincronizacao incremental](https://developers.google.com/workspace/calendar/api/guides/sync)
- [HL7 FHIR Appointment](https://www.hl7.org/fhir/appointment.html)
