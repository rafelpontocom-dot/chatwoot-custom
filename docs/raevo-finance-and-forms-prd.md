# PRD: Financeiro Asaas e Raevo Formulários

Status: em desenvolvimento

## Progresso atual

O P0 já possui módulo Financeiro opt-in por conta, seleção de mercado, conexão Asaas cifrada no servidor e tela administrativa exclusiva para quem possui configuração financeira. O núcleo cria/reutiliza o cliente Asaas por contato, persiste a cobrança com referência imutável e recebe eventos de pagamento de forma idempotente. Se a criação no Asaas expirar, o CRM consulta a cobrança por essa referência antes de permitir nova tentativa; se o Asaas a rejeitar, não fica uma cobrança local em rascunho. A criação local já registra e publica `finance.payment.created`; um webhook posterior de criação do provedor continua na auditoria, mas não repete a automação comercial. A visão Financeiro lista cobranças recentes com contato, oportunidade e responsável, permite filtrar por status, vencimento, responsável e dados comerciais, e disponibiliza o link retornado pelo provedor. Tanto na oportunidade como na lista financeira, uma cobrança vinculada à conversa pode preparar o link no rascunho do composer, sem enviar mensagem automática. A aba `Financeiro` da oportunidade exibe campos derivados de leitura: status financeiro, valor recebido e último pagamento. Cada cobrança abre um detalhe seguro com valor, vencimento, método, link/fatura e linha do tempo. Cada cobrança possui linha do tempo segura e, quando vinculada à oportunidade, seus eventos financeiros normalizados podem iniciar automações comerciais sem expor payloads brutos do provedor. Entregas autenticadas de webhook são guardadas cifradas no servidor; falhas ficam em uma fila de revisão com erro sanitizado e podem ser reprocessadas por administrador, sem retornar corpo, segredo ou payload do provedor. Em Portugal, a conta pode ativar `Controle manual`: registra cobranças externas em EUR, permite confirmar o recebimento ou cancelar com confirmação explícita e grava eventos que alimentam o mesmo fluxo comercial, sem alegar que existe integração automática. O cancelamento não representa estorno ou devolução de valor pago. A visão geral agora traz totais filtráveis de em aberto, recebido e vencido, separados por moeda.

Formulários comerciais P0 agora possuem catálogo administrativo exclusivo para administradores, modelos versionados e links públicos gerais ou individuais. O editor visual separa estrutura, prévia interativa e propriedades essenciais, permitindo que a secretaria monte o formulário pela experiência do paciente; detalhes técnicos permanecem recolhidos. A biblioteca inclui blocos comerciais iniciais e seções reutilizáveis salvas por conta, sem compartilhar respostas, tokens ou dados clínicos. A criação oferece começo em branco, captação de lead ou pré-consulta, sempre como primeira versão editável e com mapeamento explícito de contato. O formulário público só recebe schema publicado, nunca IDs de CRM, mapeamentos ou destino comercial. A pessoa configura nome de marca, política de privacidade e uma aparência acessível por preset, sem injetar CSS ou HTML livre. Cada resposta é validada no navegador e no servidor, protegida por limite de envio e honeypot, persistida como documento versionado e pode localizar/criar contato pelo mapeamento explícito. Apenas respostas de perguntas visíveis e não técnicas são persistidas e encaminhadas ao CRM. Quando o modelo declara um funil, etapa, caixa e política válidos, a resposta cria ou reaproveita a oportunidade aberta; se esse destino falhar, a submissão continua preservada para revisão. O catálogo permite abrir a resposta autorizada pela versão que a recebeu, e a oportunidade permite gerar um convite individual, acompanhar resumos de convites/respostas e preparar o link no rascunho da conversa vinculada. Convites individuais mantêm rascunho seguro no servidor para que a pessoa retome o preenchimento: só perguntas publicadas e não anexos são guardados; o rascunho comercial fica isolado por convite e o clínico é cifrado, ambos removidos no envio final. A anamnese P1 já é um modelo clínico separado: exige consentimento, só pode ser enviada por convite individual vinculado ao paciente, usa uma vez, não tem link público geral, não atualiza CRM, não publica evento de automação e cifra as respostas no servidor. Perguntas de documento clínico aceitam até cinco PDFs/imagens permitidos por envio e só aparecem no detalhe administrativo, com download auditado. O administrador define profissionais e equipes do próprio cliente que podem ler cada anamnese; sem seleção, só administradores leem. O detalhe autorizado mostra o consentimento aceito a partir da versão imutável publicada, com tipo de aceite e horário do envio; administradores também veem uma trilha de acessos sem conteúdo clínico. Nada disso é apresentado como assinatura eletrônica qualificada. CAPTCHA externo e retenção configurável estão disponíveis; varredura antimalware continua como evolução dependente do provedor de armazenamento.

### Decisão de vínculo e editor de formulários

- Um formulário comercial não publica sem destino CRM: funil, etapa, caixa e política de oportunidade. O link público localiza/cria o contato e cria ou reaproveita obrigatoriamente a oportunidade naquele destino. Convites individuais comerciais e clínicos exigem sempre o mesmo contato e oportunidade.
- A anamnese é somente por convite individual, de uso único, ligada ao paciente e à oportunidade. Respostas clínicas continuam cifradas, auditadas e fora dos campos comuns do Kanban.
- `Abrir prévia` abre uma página privada temporária que usa o mesmo renderer e layout do link público, sem persistir resposta. A prévia fica fora do editor para a secretaria enxergar a experiência real da pessoa respondente.
- Cada modelo escolhe uma experiência de resposta antes de publicar: `Guiada` apresenta uma pergunta por vez, com foco, avanço e progresso para captação e pré-consulta curta; `Por seções` agrupa perguntas para anamnese e formulários extensos. Ambas usam o mesmo renderer em prévia, convite e link público.
- Blocos de imagem aceitam upload direto de PNG, JPEG ou WebP de até 5 MB; o editor insere uma URL gerenciada pelo CRM e mantém URL externa como alternativa para conteúdos já hospedados.
- O construtor usa blocos Vue próprios: título, texto rico seguro, imagem com legenda, divisor, grupos de perguntas e uma ou duas colunas responsivas. O texto rico pode incluir listas, ênfase e links HTTP(S) seguros para políticas e orientações. Tiptap é usado apenas para o conteúdo rico permitido; HTML, JavaScript e CSS arbitrários não são aceitos.

Produtos relacionados: [Kanban Comercial](./kanban-sales-prd.md), [Agenda Operacional](./kanban-calendar-prd.md) e [Editor de Automações](./kanban-visual-workflows-prd.md)

## Decisão de produto

O RAEVO terá dois módulos nativos e independentes, unidos pela oportunidade:

1. **Financeiro**: cria e acompanha cobranças, links, recebimentos e notas fiscais por meio de um provedor de pagamento/faturação pertencente à conta do cliente. Asaas é o primeiro conector brasileiro.
2. **Formulários**: cria e recebe formulários públicos configuráveis, incluindo pré-consulta e anamnese, com vínculo seguro a contato e oportunidade.

Não criaremos uma aplicação ou repositório por cliente. Uma única base multiempresa entrega páginas com marca, idioma, campos e regras configurados pela conta. O frontend público pode futuramente usar infraestrutura de borda, mas respostas, autorização, tokens e regras continuam no backend do RAEVO.

## Problemas

### Financeiro

Hoje a venda é conduzida no WhatsApp, mas cobrança, confirmação de pagamento e nota fiscal vivem em ferramentas separadas. A secretaria perde contexto, repete dados e move uma oportunidade manualmente mesmo quando o pagamento já foi confirmado.

### Formulários

Clientes usam Google Forms, Typeform, formulários próprios, N8N e planilhas para captação, pré-consulta e anamnese. Respostas não chegam de modo confiável ao contato/oportunidade; dados clínicos podem acabar expostos no Kanban ou em conversas de pessoas que não deveriam vê-los.

## Objetivos

- Permitir criar cobrança e enviar um link de pagamento a partir da oportunidade.
- Usar webhooks Asaas como fonte confiável de status financeiro e fiscal.
- Exibir situação financeira e histórico sem misturar dados financeiros com conversa.
- Permitir formulários reutilizáveis, com campos condicionais e mapeamento explícito para CRM.
- Relacionar uma resposta ao contato e à oportunidade corretos, inclusive por link individual enviado no WhatsApp.
- Tratar anamnese e demais dados de saúde como informação sensível, com permissões, auditoria e retenção.

## Não objetivos

- Processar dados de cartão no RAEVO.
- Construir emissor fiscal próprio ou substituir contabilidade/ERP.
- Tornar Asaas, Google Agenda, FEEGOW ou N8N uma segunda fonte de verdade do CRM.
- Construir prontuário, prescrição, evolução clínica ou assinatura digital com validade jurídica no P0.
- Copiar todo o universo de formulários/automação de Typeform, Jotform ou N8N.

## Princípios

1. **A oportunidade é o contexto comercial; a cobrança é uma entidade própria.** Uma oportunidade pode ter várias cobranças, tentativas, parcelas e notas.
2. **Webhook confirma, navegador informa.** Retorno de `successUrl`, visualização do checkout ou envio de mensagem nunca confirma pagamento.
3. **Integração por conta, nunca por usuário.** A chave Asaas pertence à conta Raevo e fica cifrada no servidor; a UI jamais a mostra novamente.
4. **Sem duplicidade silenciosa.** O identificador de cliente Asaas é persistido por conta/contato e eventos externos são idempotentes.
5. **Formulário não é campo do Kanban.** A submissão é um documento versionado; somente campos mapeados entram no contato ou oportunidade.
6. **Dados de saúde ficam separados.** Eles não aparecem automaticamente na conversa, no cartão compacto ou em automações externas.
7. **Acesso mínimo necessário.** Secretaria pode coletar e acompanhar pendência; acesso ao conteúdo clínico depende de permissão explícita.
8. **Módulo é opt-in por conta.** Financeiro permanece invisível para contas que não o contrataram/configuraram; ativar não obriga escolher um provedor naquele momento.
9. **Provedor não define o produto.** A interface e o modelo financeiro usam estados normalizados. Asaas, Easypay, ifthenpay e emissores fiscais são adaptadores, não caminhos paralelos da UI.
10. **Valor é determinístico.** Valores são armazenados sempre em centavos e na moeda da cobrança; exibição, vencimento e automações usam a moeda e o fuso da conta, nunca o navegador do agente.
11. **Desativar não perde recebimento.** Desativar o módulo interrompe novas cobranças e esconde a operação, mas mantém a captura de webhooks das cobranças pendentes já criadas. Desconectar o provedor é uma ação separada, auditada e confirmada.
12. **Fiscal exige cadastro pronto.** NF não é apenas um botão sobre uma cobrança recebida: só pode ser ativada depois de validar perfil fiscal, serviço, série e elegibilidade do provedor para aquela conta.

### Permissões financeiras

- Sem função personalizada, administrador e agente podem consultar cobranças, criar links e gerir cobranças manuais; somente administrador configura provedores ou solicita estorno.
- Uma função personalizada substitui esse padrão por permissões explícitas: `finance_view`, `finance_create`, `finance_manage`, `finance_refund` e `finance_configure`.
- Credenciais, URL técnica do webhook, reprocessamento e ativação do módulo nunca aparecem para quem não possui `finance_configure`.

## Disponibilidade por conta e país

O superadministrador/administrador da conta terá `Configurações > Módulos`, com uma linha `Financeiro`:

- estado `Desativado`, `Ativo sem provedor`, `Ativo e conectado` ou `Requer atenção`;
- ativação por conta, auditada com usuário/data;
- escolha de país/mercado operacional: `Brasil`, `Portugal` ou `Outro`;
- catálogo de provedores compatível com o mercado selecionado;
- permissões financeiras permanecem desligadas até que o módulo esteja ativo.

P0 disponibiliza o módulo para contas que ativarem `Brasil + Asaas` ou `Portugal + Controle manual`. O controle manual cria cobranças externas em EUR sem credenciais, checkout ou webhook; a secretaria confirma o recebimento somente após a verificação fora do RAEVO. Cobranças manuais abertas passam automaticamente para `Vencida` após a data de vencimento e registram o evento comercial correspondente uma única vez. Ele permite iniciar o piloto sem fingir integração automática.

Para a fase atual do RAEVO, focada em clínicas e procedimentos pontuais, a direção aprovada para o piloto português é **ifthenpay para recebimentos + Moloni para faturação**, após validar uma conta real e o contador do cliente. A escolha privilegia referências Multibanco, MB WAY, links/callbacks e menor custo público para MB WAY; não pressupõe recorrência.

P1 mantém as seguintes alternativas sob avaliação:

- **ifthenpay**: conector preferencial para referências Multibanco, MB WAY, links e callbacks.
- **Moloni**: emissor fiscal preferencial para documentos, faturas, recibos e notas de crédito.
- **Easypay**: alternativa para cliente que realmente precise de um catálogo maior de meios, débito direto, recorrência, Apple Pay/Google Pay ou condições comerciais de volume melhores.

O RAEVO não prometerá emissão fiscal portuguesa nativa sem validação de contador, série documental, requisitos da Autoridade Tributária e conta real do cliente.

## Personas e jornadas

### Gestor: conectar Asaas

1. Abre `Financeiro > Configurações > Asaas`.
2. Escolhe ambiente de produção ou sandbox.
3. Informa a chave de API, nome de exibição da conta e, opcionalmente, política de emissão de NF.
4. O RAEVO testa a conexão no servidor e mostra conta, ambiente, última sincronização e saúde do webhook.
5. A chave passa a aparecer somente como máscara e pode ser substituída ou desconectada por administrador.

O painel não tenta incorporar a tela administrativa do Asaas nem pedir senha de login do usuário. A conta é conectada por chave/API aprovada pelo administrador.

### Gestor: liberar módulo para uma conta

1. Abre `Configurações > Módulos` no contexto da conta.
2. Ativa `Financeiro` e escolhe o mercado operacional.
3. Para Brasil, seleciona Asaas e é levado para a conexão da conta.
4. Para Portugal, ativa `Controle manual` para registrar cobranças externas ou escolhe `Easypay (piloto)`, `ifthenpay (piloto)` ou `Moloni fiscal (piloto)` apenas quando o adaptador estiver liberado.
5. A tela apresenta claramente capacidades disponíveis: cobrar, confirmar, reembolsar, emitir fatura/NF e métodos locais.

A alteração não apaga cobranças anteriores. Desativar o módulo bloqueia novas ações e preserva histórico para consulta conforme a permissão da conta.

### Secretaria: cobrar uma oportunidade

1. Abre a oportunidade e entra na aba `Financeiro`.
2. Escolhe `Nova cobrança`, valor, vencimento, formas aceitas e descrição.
3. O RAEVO localiza/cria o cliente Asaas a partir do contato e cria uma cobrança individual.
4. Exibe a fatura/checkout hospedado pelo Asaas e oferece `Copiar link` e `Enviar no WhatsApp`.
5. O webhook atualiza a linha do tempo e os indicadores da oportunidade.
6. Se configurado, um evento financeiro dispara a automação comercial ou a emissão de NF.

### Financeiro: emitir e acompanhar NF

1. Abre uma cobrança recebida que permite emissão fiscal.
2. Revisa serviço, valor, tomador e dados fiscais antes da emissão.
3. Solicita emissão pelo Asaas.
4. A linha do tempo acompanha criada, enviada, autorizada, cancelada ou erro.
5. Após autorização, a pessoa abre PDF/XML pelo RAEVO ou envia o documento ao cliente conforme regra.

### Paciente: preencher anamnese por convite

1. Recebe no WhatsApp um link individual, limitado e com marca da clínica.
2. Vê finalidade, política de privacidade e consentimento destacado.
3. Preenche seções curtas, com condicionais e opção de salvar/retomar apenas quando essa função estiver configurada.
4. A resposta fica vinculada ao contato e à oportunidade já conhecidos.
5. A secretaria abre respostas comerciais pelo histórico da própria oportunidade, sem sair do atendimento; respostas clínicas continuam visíveis apenas a profissionais autorizados e administradores.

## Escopo P0

### Financeiro Asaas

- Menu principal `Financeiro`, com visão de cobranças da conta e filtros por estado, vencimento, responsável e oportunidade.
- Flag/entitlement `finance_module_enabled` por conta, com ativação auditada e sem menu/rotas para contas desativadas.
- Aba `Financeiro` na oportunidade.
- Configuração Asaas por conta: ambiente, chave, teste, estado de conexão, última sincronização, endpoint de webhook e token de validação mascarado.
- Criar cobrança avulsa vinculada a contato e oportunidade.
- Formas: Pix, cartão, boleto e indefinida quando suportadas pela conta Asaas.
- Exibir link/fatura, vencimento, valor, status, método e linha do tempo.
- Ação de copiar/enviar o link pelo editor de mensagem já existente.
- Modelo de automação comercial: o gatilho `Cobrança criada` segue para o nó `Enviar mensagem` com `Link da cobrança`, `Valor da cobrança` e `Vencimento da cobrança`. O link é resolvido pela cobrança do evento, inclusive depois de uma espera; consentimento, janela de WhatsApp, template oficial, horário silencioso e limite de frequência continuam obrigatórios.
- Webhooks de cobrança idempotentes e auditados.
- Campos derivados, de leitura: status financeiro, valor recebido, data de pagamento e última cobrança.
- Integração no Vue Flow: gatilhos de cobrança criada, vencida, confirmada, recebida, estornada e chargeback.
- Para Portugal, `Controle manual`: cobrança externa em EUR, confirmação de recebimento e cancelamento auditados, sem checkout ou webhook.
- Reconciliação operacional dirigida: somente cobranças com estado antigo, entrega de webhook em atenção ou divergência explícita são verificadas contra o provedor sem criar uma segunda cobrança; diferenças entram em fila administrativa sanitizada.
- Valores recebidos são registrados separadamente do valor solicitado, permitindo visualizar pagamento parcial ou divergência sem marcar a cobrança como recebida por engano.
- Desativar o módulo bloqueia ações novas, mas mantém webhooks de cobranças pendentes. A desconexão do provedor exige confirmação explícita, mostra o total de cobranças não terminais afetadas e registra o responsável.

### Formulários

- Menu `Formulários` para administradores, com lista de modelos, respostas e configurações.
- Modelos de captação e pré-consulta com título, descrição, nome de marca exibido, aparência por preset acessível (`Clara e profissional`, `Acolhedora` ou `Alto contraste`), idioma `pt-BR` ou `pt-PT` e URL pública. A marca pode usar logo enviada em PNG, JPEG ou WebP até 2 MB, ou uma URL HTTPS como alternativa.
- Tipos: texto curto/longo, e-mail, telefone, número, moeda, data, seleção, múltipla seleção, checkbox, aviso/consentimento e campos ocultos de contexto. Cada pergunta pode ter texto de apoio curto, exibido junto ao campo e associado de forma acessível.
- Seções, obrigatoriedade, condicionais simples e validação de servidor. Cada seção pode ter descrição curta para orientar o respondente; seções e perguntas podem ser reordenadas por controles acessíveis, sem depender de arrastar.
- Versões imutáveis: publicar uma alteração cria nova versão; respostas antigas preservam a estrutura original e o administrador consulta o histórico somente leitura por número e data.
- Link geral e convite individual com token aleatório, expiração e número máximo de usos. Convite individual comercial ou clínico exige contato e oportunidade; quando vence, passa a aparecer como `Expirado` no histórico e deixa de abrir o formulário. Um administrador pode revogar apenas um convite ainda disponível, com confirmação; o link deixa de abrir sem apagar as respostas já recebidas. Anamnese só aceita convite individual vinculado ao contato e de uso único.
- Localizar/criar contato por e-mail/telefone; vincular a oportunidade existente, aberta recente ou criar oportunidade, conforme regra configurada. Um link público comercial só pode ser publicado após mapear Nome e Telefone ou E-mail para o contato. Telefones nacionais informados em formulários configurados em Português do Brasil ou Portugal são normalizados para E.164 no servidor; outros idiomas exigem código internacional explícito.
- Mapeamento explícito de respostas comerciais para atributos de contato e destino comercial da oportunidade. O P1 inicial também permite mapear uma resposta compatível para um campo personalizado do card do funil de destino; fórmulas nunca recebem valor de formulário. Anamnese não possui mapeamento para CRM.
- Área separada de respostas e histórico de envio/conclusão.
- Antispam: rate limit e honeypot; CAPTCHA externo configurável entra no P1.

### Limite explícito do P0

A anamnese P1 é uma coleta clínica protegida, não um prontuário completo: não há prescrição, evolução clínica ou integração externa. Administradores podem exportar uma resposta em JSON auditado, sem anexos; profissionais com acesso clínico continuam sem direito de exportação. Documentos clínicos aceitam PDF, JPG, PNG, HEIC ou HEIF, até 10 MB por arquivo e cinco por envio; não são expostos em listagens, eventos, CRM ou URL pública. A clínica precisa configurar as chaves de criptografia antes de publicar o modelo e definir a matriz de acesso antes de liberar o uso operacional.

## Escopo P1

### Financeiro

- Parcelamento, cobrança recorrente e assinaturas.
- Primeiro piloto de Portugal com ifthenpay, validando MB WAY, Multibanco, callbacks, sandbox, reembolso e suporte em uma clínica real.
- Primeiro piloto de faturação portuguesa com Moloni, validando requisitos fiscais, séries documentais e contador do cliente.
- Easypay permanece como alternativa de produto para contas que precisem de meios/recorrência além do escopo clínico atual.
- Checkout Asaas com expiração, cancelamento e retorno de navegação.
- Política para criar NF após recebimento e catálogo simples de serviços fiscais.
- Perfil fiscal por conta antes de habilitar NF: razão social, documento fiscal, endereço, município/país, serviço padrão e série quando aplicável. O perfil é validado com o provedor e com o contador do cliente no piloto.
- PDF/XML, reenvio e histórico de erros fiscais.
- Totais filtráveis de em aberto, recebido e vencido já entregues; relatórios por estorno, etapa e origem continuam como evolução.
- Cancelamento de cobrança pendente ou vencida já entregue; solicitação de estorno continua sujeita a permissão, confirmação e regras específicas do meio de pagamento.
- Solicitação de estorno total Asaas já entregue para Pix e cartão em cobranças confirmadas ou recebidas, com confirmação explícita e status final somente por webhook. Estorno parcial, boleto e outros meios permanecem em P1 específico.
- Notificações internas de vencimento/atraso e cadência comercial sem duplicar notificações do Asaas.

### Formulários

- Modelo `Anamnese` entregue com campos de saúde, consentimento obrigatório, convite individual de uso único, resposta cifrada e auditoria de leitura administrativa. O administrador pode liberar leitura por formulário para profissionais ou equipes existentes; esse acesso não concede edição, exportação ou acesso a outros formulários. A configuração usa busca e listas com rolagem própria, para permanecer viável em contas com equipes grandes.
- Anexos privados de anamnese já entregues: apenas em convite clínico individual, allowlist de PDF/imagem, limite de 10 MB por arquivo e cinco por envio, sem URL pública, com download administrativo auditado. A retenção é opt-in por modelo: sem prazo não há descarte; com prazo explícito, o agendador diário remove respostas cifradas, anexos e metadados operacionais, preservando a submissão descartada e sua auditoria. Varredura antimalware permanece pendente antes de liberar anexos clínicos em escala.
- Logo e kit visual administrados por conta, com variantes acessíveis e revisão de contraste antes da publicação.
- Biblioteca inicial de blocos comerciais e blocos salvos pela própria conta: dados de contato, preferência de agenda, origem/interesse e seções reutilizáveis. Um bloco salvo preserva somente a estrutura comercial da seção, nunca respostas, destino CRM, tokens ou informações clínicas. Um modelo publicado também pode ser duplicado como cópia privada, com novo nome/link e schema independente, sem respostas, convites ou publicação herdados. Biblioteca de modelos por setor e blocos clínicos compartilhados continuam como evolução.
- Editor visual por blocos: estrutura e biblioteca pesquisável à esquerda, formulário em largura real ao centro e configuração contextual em modal. A biblioteca adiciona perguntas, conteúdo e blocos salvos diretamente na seção ativa; opções de seleção são escritas uma por linha. A secretaria monta o formulário vendo a experiência da pessoa respondente, sem precisar navegar por chaves, destinos CRM ou regras técnicas. O destino, publicação e integrações ficam na área avançada do formulário; condição de exibição e mapeamento de contato/oportunidade ficam nas configurações avançadas da pergunta, junto da própria pergunta.
- `Abrir prévia` usa o renderer público real, em nova página privada, com respostas temporárias e sem envio. Etapas e perguntas podem ser reordenadas visualmente; controles de mover acima/abaixo continuam como alternativa de teclado.
- O editor mantém um rascunho local da configuração não publicada, avisa antes de sair com alterações e mostra uma lista curta do que falta antes da publicação. O rascunho nunca contém respostas de pacientes e a publicação continua criando uma versão imutável no servidor.
- A leitura de respostas deve acompanhar as seções do formulário, com perguntas e respostas agrupadas, especialmente para anamnese. A conta pode configurar nome, descrição, tema e logo do formulário; uma logo enviada em PNG, JPEG ou WebP até 2 MB tem prioridade, e a URL HTTP(S) permanece como alternativa.
- Assinatura de aceite visual por nome digitado, sem alegar assinatura eletrônica qualificada ou substituir assinatura digital com validade jurídica.
- O evento comercial `Formulário recebido` já pode iniciar uma regra do Vue Flow quando a submissão estiver vinculada a uma oportunidade; ele carrega somente IDs permitidos e nunca respostas. `Formulário enviado` só ocorre quando o Chatwoot cria uma mensagem pública de saída com aquele link na conversa vinculada, não ao gerar ou copiar a URL. `Formulário iniciado` também pode iniciar uma regra quando um convite individual comercial é aberto pela primeira vez; ele registra somente IDs da conta, oportunidade, convite e modelo, jamais token ou respostas. `Prazo do formulário expirado` é processado pelo agendador a cada cinco minutos e segue a mesma projeção segura. O administrador pode optar por `Formulário não aberto` e definir de 1 hora a 30 dias: ele só ocorre uma vez, após convite comercial enviado permanecer sem abertura. Também pode configurar `Resposta crítica` para uma pergunta e valor exato; em perguntas de seleção, escolhe uma opção publicada. O evento transmite apenas IDs permitidos. Anamnese não publica nenhum desses eventos.
- Evoluir o mapeamento de campos personalizados para transformações declarativas e campos compostos, mantendo a validação de tipo, regras do board e controle de concorrência já entregues no P1 inicial.
- Resumo por IA somente para usuários autorizados, com aviso de que é apoio e link para a fonte original.
- Exportação JSON de resposta entregue somente para administradores, sem anexos e com auditoria. A retenção por modelo exige prazo definido pela clínica com jurídico/DPO; o padrão é não descartar automaticamente.

## Escopo P2

- Conciliação financeira, split, múltiplas contas Asaas e integração ERP.
- NF por provedor adicional, quando não suportada pelo Asaas.
- Autorização granular por unidade, profissional, formulário e campo sensível.
- Retorno autenticado por portal de paciente e gestão de identidade própria; o rascunho atual já pode ser retomado em qualquer dispositivo que possua o link individual, mas não vincula sessões autenticadas de pacientes.
- Integração de fontes externas por conexões aprovadas no Vue Flow/N8N, com allowlist de campos.
- Portal de paciente para consultar formulários, pagamentos e agendamentos.

## Telas

### Financeiro > Visão geral

Cabeçalho compacto: período, busca, filtros e `Nova cobrança`. Abaixo, uma tabela/lista com status, contato, oportunidade, vencimento, valor, método e responsável. Métricas ficam recolhidas e só aparecem ao acioná-las.

### Financeiro > Configurações > Asaas

Uma tela de configuração progressiva, não um formulário gigante:

- estado: desconectado, verificando, conectado, webhook com atenção ou erro;
- cartão de conexão: ambiente, conta exibida e última validação;
- ação `Conectar conta Asaas` abre modal com chave de API e ambiente;
- ação `Trocar chave` pede nova chave, sem revelar a anterior;
- bloco técnico recolhido: URL do webhook, token de validação, tentativas recentes e botão de copiar;
- bloco fiscal recolhido: emissão habilitada, serviço padrão e alertas municipais;
- ações destrutivas exigem confirmação e permissão financeira.

### Configurações > Módulos > Financeiro

O módulo é habilitado antes da conexão. A tela é uma linha compacta, não um novo painel administrativo:

- toggle com estado e explicação comercial;
- seletor de mercado, que muda a lista de conectores disponíveis;
- capacidades resumidas por conector, como `Pix`, `MB WAY`, `Multibanco`, `cartão`, `cobrança recorrente` e `faturação`;
- botão contextual `Configurar Asaas` ou `Configurar provedor`;
- aviso de que desativar impede novas cobranças, mas preserva o histórico.

### Oportunidade > Financeiro

No topo: valor comercial e status financeiro atual. Abaixo, lista cronológica de cobranças compactas. Cada item abre detalhe lateral com link, QR/fatura quando disponível, eventos e ações permitidas. Não há campos técnicos, IDs externos ou payloads expostos à secretaria.

### Formulários > Modelos

Lista tranquila de modelos, respostas e ação `Criar formulário`. A edição acontece em detalhe progressivo: informações e link público, destino CRM opcional e seções/campos. Publicar cria uma nova versão imutável e atualiza a URL do modelo sem alterar respostas anteriores.

### Oportunidade > Formulários

Lista de convites e submissões. Mostra nome do modelo, status, data e quem respondeu. Conteúdo sensível não aparece no resumo; o botão `Abrir resposta` é protegido por policy.

## Métricas de sucesso

- 95% das cobranças criadas no CRM chegam ao estado final por webhook sem intervenção manual.
- Nenhuma oportunidade é marcada como paga por redirect de navegador.
- Menos de 2% de clientes Asaas duplicados após o fluxo de cobrança individual.
- 90% dos formulários enviados ficam vinculados automaticamente a contato/oportunidade.
- Zero acesso de secretaria a respostas clínicas quando não possui permissão.

## Critérios de aceite

### Financeiro P0

- Administrador conecta, testa, troca e desconecta uma conta Asaas sem que a chave anterior seja retornada pela API ou UI.
- Conta sem `finance_module_enabled` não vê menu, rotas, campos derivados ou ações financeiras; acesso direto é negado no servidor.
- Ativar/desativar módulo é auditado, preserva pagamentos existentes e não permite desativação acidental: a interface pede uma segunda confirmação e a API exige `confirm_disable=true` na mudança de ativo para desativado.
- País selecionado limita provedores e métodos oferecidos pela UI; uma conta portuguesa não recebe rótulos Pix/Boleto como opções padrão.
- A criação de cobrança usa o contato vinculado e persiste a referência Asaas por conta, evitando recriação desnecessária. Se uma chamada de criação expirar, o CRM concilia a cobrança pela referência antes de pedir nova tentativa.
- A secretaria consegue copiar ou enviar uma fatura/link sem sair da oportunidade.
- A secretaria padrão consulta, cria cobranças e gere cobranças manuais. Credenciais, módulo, reprocessamento de webhook e estorno exigem permissão financeira explícita.
- Uma automação de `Cobrança criada` pode enviar somente o link da cobrança que a originou; nunca seleciona silenciosamente outro pagamento do mesmo contato.
- Um link de cobrança não é enviado automaticamente por padrão. A automação deve escolher o evento, a mensagem, o canal e a política de frequência; a linha do tempo registra o vínculo da mensagem com a cobrança, sem expor o link em logs.
- Recebimento, atraso, estorno e chargeback atualizam o mesmo pagamento uma única vez mesmo com webhook repetido.
- Valor, moeda, data de vencimento e status são exibidos de forma consistente no fuso da conta; uma diferença de valor recebido fica visível como pendência de conciliação, não como sucesso silencioso.
- Um redirect de pagamento não altera estado financeiro sem webhook confirmado.
- Usuário sem permissão não cria, cancela, estorna, emite NF nem consulta configurações da conta.
- Falha de webhook fica auditada, reprocessável e não expõe segredo/payload sensível na interface.
- A saúde da conexão evidencia fila de webhook interrompida, eventos pendentes e última entrega. O processamento responde rapidamente e segue em job idempotente, para não provocar nova tentativa por lentidão do CRM.
- Desativar o módulo não descarta atualização de cobrança pendente; desconectar o provedor exige confirmação de impacto e produz evento de auditoria.

### Formulários P0

- Um modelo publicado abre em URL pública apenas para a conta correta.
- Link público geral só abre para modelo comercial, ativo e publicado; schema, mapeamento e destino CRM não são expostos ao navegador.
- Convite individual expirado, consumido ou adulterado não expõe formulário/resposta.
- Submissão com telefone/e-mail vincula ou cria contato conforme política e respeita deduplicação.
- Um link público comercial sem mapeamento de Nome e Telefone ou E-mail não pode ser publicado nem ativado; o editor aponta a pendência antes de gerar o link.
- Destino CRM configurado cria/reaproveita oportunidade somente no funil, etapa e caixa da mesma conta; erro de destino não apaga a resposta.
- Apenas os mapeamentos declarados atualizam contato/oportunidade; respostas não mapeadas permanecem no documento da submissão.
- Alterar modelo publicado cria nova versão, sem modificar respostas anteriores.
- Condicionais e obrigatoriedade são validadas no backend, não só no navegador.
- Modelos clínicos nunca possuem link público geral. A anamnese entregue só abre por convite individual de uso único vinculado ao contato, cifra respostas e audita a leitura detalhada e o download de documento. Administradores têm acesso total; profissional ou equipe só vê a anamnese para a qual foi explicitamente liberado. Exportação e permissões por unidade/por campo continuam em P2.
- Upload clínico usa armazenamento privado, valida MIME/extensão e tamanho, não serializa URL no dashboard e exige autorização no download. Retenção configurável por modelo é entregue com descarte auditado e padrão sem expiração; varredura antimalware continua pré-requisito de escala. Links públicos comerciais podem habilitar Cloudflare Turnstile por formulário, com chave pública no navegador e validação da chave secreta apenas no servidor.

## Riscos e decisões em aberto

- **Fiscal:** validar com contador quais municípios e serviços cada cliente usará antes de prometer emissão automática.
- **LGPD e saúde:** clínica é controladora; RAEVO tende a operar como operador. Contratos, bases legais, retenção e encarregado devem ser revisados com jurídico/DPO.
- **Comunicação:** definir se Asaas ou RAEVO envia cada lembrete financeiro para evitar mensagens duplicadas.
- **Anamnese:** antes de cada clínica publicar um modelo sensível, configurar a chave de criptografia, a matriz de acesso e a retenção com jurídico/DPO.

Referências: [Asaas - guia de cobranças](https://docs.asaas.com/docs/guia-de-cobrancas), [criação de webhooks via API](https://docs.asaas.com/docs/create-new-webhook-via-api), [FAQ de webhooks](https://docs.asaas.com/docs/webhooks-faq), [webhooks de NF](https://docs.asaas.com/docs/webhook-para-notas-fiscais), [LGPD](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709compilado.htm).
