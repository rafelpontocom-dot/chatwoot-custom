# Ideias Futuras: RAEVO CRM

Este documento registra possibilidades de produto fora do escopo comprometido dos PRDs e specs ativos. Cada item precisa de descoberta, desenho de privacidade, criterios de aceite e priorizacao antes de entrar em desenvolvimento.

## IA: Resumo Da Conversa Para Atendimento

### Problema

Quando o medico abre uma consulta, precisa recuperar rapidamente o contexto comercial e operacional da conversa no WhatsApp. Ler toda a conversa toma tempo e aumenta o risco de perder informacoes relevantes, como motivo do contato, necessidades declaradas, procedimento de interesse, preferencias de horario e combinados anteriores.

### Proposta

Na consulta ou no drawer de agendamento, disponibilizar um bloco `Resumo da conversa` gerado por IA a partir das mensagens vinculadas ao contato, oportunidade e conversa escolhida.

O resumo deve ajudar o profissional a se preparar, nunca substituir a leitura da conversa nem produzir diagnostico clinico.

### Conteudo Sugerido

- motivo declarado pelo cliente para procurar atendimento;
- contexto comercial: procedimento, valor ou plano mencionado, quando houver;
- preferencias e restricoes de agenda;
- duvidas ainda abertas;
- combinados, proximas acoes e mensagens pendentes;
- linha do tempo curta com os fatos mais recentes;
- alertas de incerteza: informacao ausente, contraditoria ou antiga.

### Experiencia

1. A secretaria ou o medico abre o detalhe do agendamento.
2. O bloco mostra a data de geracao e a conversa de origem.
3. `Atualizar resumo` gera novamente apenas quando solicitado ou quando houver novas mensagens relevantes.
4. `Ver conversa` abre o atendimento original no Chatwoot.
5. O usuario pode marcar o resumo como util ou reportar problema para futura avaliacao da qualidade.

### Regras De Seguranca E Privacidade

- nunca inventar fatos, diagnosticos, prescricoes ou dados clinicos;
- apresentar trechos como informacao relatada pelo cliente, nao como verdade clinica;
- nao enviar o resumo automaticamente para WhatsApp, email ou integracoes externas;
- respeitar permissoes da conta, conversa e oportunidade;
- registrar apenas metadados de auditoria, sem expor prompt, tokens ou conteudo sensivel em logs;
- permitir desabilitar por conta ou por board;
- definir retencao e consentimento antes de disponibilizar em ambientes clinicos.

### Dependencias E Decisoes Futuras

- definir modelo, custo, limite de tamanho e estrategia de atualizacao incremental;
- definir quais conversas podem alimentar o resumo quando o contato tiver varias oportunidades;
- criar avaliacao com casos reais anonimizados antes de liberar;
- decidir se o resumo pertence a oportunidade, agendamento ou ambos;
- validar requisitos de LGPD e responsabilidades da clinica.

### Criterio Para Virar P0/P1

Entrar no roadmap somente depois de validarmos que o profissional economiza tempo sem perder contexto e que o resumo se mantem fiel, auditavel e claramente separado de qualquer anotacao clinica.
