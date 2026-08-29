# Spec: Financeiro Asaas e Raevo Formulários

Baseado em: [PRD Financeiro Asaas e Raevo Formulários](./raevo-finance-and-forms-prd.md)

Status: Financeiro P0 concluído localmente; Formulários comerciais P0 e anamnese clínica P1 (convite individual cifrado) implementados localmente.

## Progresso atual

Implementados nesta etapa: `FinanceModuleSetting`, `FinanceProviderConnection`, catálogo de provedores, APIs administrativas e tela Financeiro. A chave Asaas é aceita apenas pelo servidor, cifrada quando as chaves de Active Record Encryption estão configuradas e nunca integra o payload público. `FinanceCustomer`, `FinancePayment` e `FinancePaymentEvent` persistem a relação por contato, a cobrança e a auditoria; o cliente Asaas cria cliente/cobrança, registra `PAYMENT_CREATED` com o ator e valida a conexão; o webhook autenticado pelo header `asaas-access-token` aplica atualizações idempotentes. Se o provedor enviar `PAYMENT_CREATED` depois da criação local, o evento do provedor fica na auditoria, porém não publica uma segunda execução comercial. Eventos que chegam fora de ordem ficam registrados com estado `ignored` e não podem regredir o estado financeiro nem disparar automações. `FinanceWebhookDelivery` armazena o corpo autenticado de cada webhook apenas no servidor, cifrado quando a instalação possui Active Record Encryption; seu JSON público contém somente status, horário, tentativas e erro sanitizado. Falha autenticada coloca a conexão em `attention` e pode ser reprocessada por administrador. A criação é idempotente também diante de timeout: o cliente consulta `externalReference`; uma recusa explícita do Asaas remove a tentativa local não confirmada. A tela Financeiro carrega cobranças recentes com oportunidade e responsável pré-carregados, filtra por status, período, responsável e contato/dados comerciais, permite buscar o contato e criar Pix, cartão ou boleto, e abre o link seguro devolvido pelo provedor. Uma cobrança com oportunidade e conversa vinculadas pode preparar esse link no rascunho da conversa tanto pela oportunidade como pela lista Financeiro. O detalhe seguro mostra valor, vencimento, método, link/fatura e eventos, sem `metadata`, segredo ou identificadores técnicos. Para Portugal, uma conexão `manual` sem segredo permite registrar uma cobrança externa em EUR, confirmá-la como recebida ou cancelá-la com auditoria, sem criar checkout ou simular webhook. `Finance::MarkOverduePaymentsJob` roda pelo agendador existente e atualiza somente cobranças manuais abertas, de contas com módulo ativo, cuja data ficou no passado; cada transição grava um único `PAYMENT_OVERDUE`. O administrador também pode solicitar um estorno total Asaas de Pix/cartão confirmado ou recebido; essa solicitação registra `PAYMENT_REFUND_REQUESTED`, não altera o estado local e não pode se repetir. Apenas `PAYMENT_REFUNDED` do webhook marca a cobrança como estornada. A oportunidade consulta apenas suas próprias cobranças, pode criar outra vinculada ao card, copiar o link ou prepará-lo no composer da conversa e apresenta um resumo derivado de status, valor recebido e último pagamento. `GET /finance/payments/summary` calcula em aberto, recebido e vencido a partir do mesmo escopo filtrado da lista, retornando grupos separados por moeda. `GET /finance/payments/:id` entrega uma linha do tempo sanitizada de eventos, sem `metadata` ou identificadores sensíveis do provedor. `POST /finance/payments/:id/cancel` chama a exclusão Asaas somente para cobranças Asaas e cancela localmente as manuais permitidas; ambos os casos gravam `PAYMENT_DELETED` com o ator. `POST /finance/payments/:id/mark_received` é exclusivo de cobranças manuais elegíveis e grava `PAYMENT_RECEIVED`. Os eventos `finance.payment.*` disponíveis no Vue Flow são publicados apenas para cobranças com `kanban_card_id`, com `account_id`, `board_id`, `card_id`, valor, moeda, estado e chave idempotente; nunca incluem o payload Asaas. A policy financeira permite consulta, criação, gestão, estorno e configuração de modo granular; agentes sem função personalizada mantêm o fluxo operacional e funções customizadas exigem uma permissão financeira explícita.

O nó `Enviar mensagem` do Vue Flow aceita `{{finance_payment_link}}`, `{{finance_payment_amount}}` e `{{finance_payment_due_on}}`. Quando o fluxo se origina em um evento financeiro, as três variáveis resolvem o pagamento cujo `payment_id` pertence ao contexto da execução. Enquanto um atraso, horário silencioso ou espera por resposta deixa o fluxo pendente, esse contexto é preservado; só em fluxos sem evento financeiro há fallback para a cobrança mais recente com link da mesma oportunidade.

O bloco comercial de Formulários existe no domínio e no dashboard: `FormTemplate` tem categoria, classificação de acesso, link público opt-in e versão ativa; `FormTemplateVersion` pertence à mesma conta, exige schema com seções e não pode ser alterada depois da publicação. A criação oferece quatro pontos de partida: em branco, captação de lead, pré-consulta e anamnese. Os modelos comerciais publicam uma primeira versão editável com mapeamento explícito de nome, telefone e e-mail; falha de publicação preserva o rascunho para correção. `FormInvitation` emite token opaco com HMAC, armazena apenas seu digest, aplica expiração e consumo transacional. As APIs autenticadas `GET/POST/PATCH /api/v1/accounts/:account_id/forms/templates`, `POST /api/v1/accounts/:account_id/forms/templates/:id/publish` e `POST /api/v1/accounts/:account_id/forms/templates/:template_id/invitations` são exclusivas de administradores. O token só sai na resposta de criação do convite e não retorna em listagens. `FormSubmission` persiste respostas permitidas pelo schema publicado e o mapeamento comercial declarado pode localizar/criar contato e criar/reaproveitar uma oportunidade em destino validado. A rota pública individual e o link geral retornam somente formulário, versão e schema sem IDs de CRM; ambos aplicam rate limit e honeypot. A anamnese `sensitive_health` não possui link público geral: exige contato conhecido, convite individual de uso único e consentimento obrigatório; as respostas são cifradas em coluna separada, não são mapeadas ao CRM nem publicam eventos. A API administrativa lista apenas resumos e entrega o conteúdo clínico somente no detalhe autorizado, registrando auditoria de leitura.

## Fronteira técnica

Os dois módulos pertencem a `Account` e usam o mesmo padrão do Kanban: controllers finos, policies por conta, serviços para regra de negócio, jobs para I/O externo e eventos somente após commit. Financeiro é habilitado por conta e utiliza adaptadores de provedor; Asaas não pode vazar para contratos, tela ou modelo compartilhado.

O módulo financeiro integra apenas pelo servidor. Chaves Asaas nunca são expostas ao dashboard, ao Vue Flow, a logs, a eventos ou ao navegador. O módulo de formulários usa rotas públicas com token opaco, mas salva dados e decide permissões no Rails.

O payload de dados de saúde não deve ser enviado a N8N, webhook, e-mail, WhatsApp ou IA por padrão. Toda integração externa usa allowlist explícita de campos não sensíveis.

## Modelo de dados

### FinanceModuleSetting

Uma configuração de disponibilidade por conta.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatório, único |
| `enabled` | boolean | padrão `false` |
| `market` | enum | `BR`, `PT`, `OTHER` |
| `default_payment_provider` | string | opcional; validado pelo catálogo |
| `default_invoicing_provider` | string | opcional; validado pelo catálogo |
| `enabled_at` / `enabled_by_id` | datetime/bigint | auditoria |
| `disabled_at` / `disabled_by_id` | datetime/bigint | auditoria |
| `settings` | jsonb | apenas preferências não secretas |

`FinanceProviderDefinition` é catálogo de código, não tabela administrável pelo cliente. Cada definição expõe `key`, mercados, moedas, métodos, capacidades e adaptador. Catálogo inicial:

| Chave | Mercado | Papel | Estado |
| --- | --- | --- | --- |
| `asaas` | BR | pagamentos e NFS-e quando suportada | P0 |
| `manual` | BR/PT/OTHER | registro manual, sem webhook | P0 |
| `ifthenpay` | PT | pagamentos pontuais | conector preferencial P1 |
| `moloni` | PT | faturação/documentos | emissor preferencial P1 |
| `easypay` | PT | pagamentos amplos/recorrência | alternativa futura |

O administrador não escolhe um candidato P1 na produção enquanto o respectivo adaptador não estiver marcado como disponível por feature flag de instalação.

### AsaasConnection

Uma conexão ativa por conta no P0.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatório, único |
| `provider` | enum | inicialmente `asaas` |
| `environment` | enum | `sandbox`, `production` |
| `api_key_ciphertext` | text | obrigatório, cifrado; nunca serializado |
| `webhook_token_ciphertext` | text | cifrado |
| `provider_account_id` | string | opcional, retornado na validação |
| `display_name` | string | opcional |
| `status` | enum | `disconnected`, `verifying`, `connected`, `attention`, `error` |
| `last_verified_at` | datetime | opcional |
| `last_webhook_at` | datetime | opcional |
| `settings` | jsonb | política de notificação e NF |
| `lock_version` | integer | optimistic locking |

Índice único: `account_id, provider`.

O nome de implementação pode evoluir para `FinanceProviderConnection`, com `provider` e `credentials_ciphertext`. O adaptador Asaas será a única implementação P0; a migração deve evitar uma tabela que force `asaas_*` em pagamentos/contatos.

### Payment

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatório, indexado |
| `contact_id` | bigint | obrigatório |
| `kanban_card_id` | bigint | opcional |
| `asaas_connection_id` | bigint | obrigatório |
| `provider_payment_id` | string | único por conexão quando presente |
| `provider_customer_id` | string | referência do cliente Asaas |
| `external_reference` | string | UUID/identificador interno imutável |
| `kind` | enum | `charge`, `checkout`, `subscription`, `installment` |
| `status` | enum | estados normalizados abaixo |
| `billing_type` | enum | `pix`, `credit_card`, `boleto`, `undefined`, `other` |
| `amount_cents` | integer | maior que zero |
| `paid_amount_cents` | integer | padrão `0`; nunca substitui `amount_cents` |
| `currency` | string | padrão `BRL` |
| `due_on` | date | opcional conforme tipo |
| `paid_at` | datetime | opcional |
| `provider_updated_at` | datetime | opcional; ordena eventos externos fora de ordem |
| `invoice_url` | text | URL externa, não segredo |
| `provider_payload` | jsonb | payload normalizado e minimizado |
| `lock_version` | integer | optimistic locking |

Estados internos P0: `draft`, `pending`, `confirmed`, `received`, `overdue`, `refunded`, `chargeback`, `canceled`, `failed`.

`billing_type` é normalizado e extensível: `pix`, `credit_card`, `boleto`, `mb_way`, `multibanco`, `sepa_direct_debit`, `bank_transfer`, `cash`, `undefined`, `other`. A UI só apresenta métodos declarados pelo adaptador e mercado da conta.

Índices: `account_id,status`, `account_id,kanban_card_id`, `asaas_connection_id,provider_payment_id` único.

Dinheiro é persistido em centavos. `due_on` representa a data comercial no fuso da conta; um adaptador que exponha hora deve preservar o instante original em `provider_payload` minimizado e serializar a data para a zona da conta. A cobrança só chega a `received` quando a transição for válida e o valor confirmado atender a regra do provedor; recebimento menor, maior ou parcial permanece explicitamente identificável por `paid_amount_cents`.

### PaymentEvent

Registro append-only de eventos recebidos e ações locais.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `payment_id` | bigint | obrigatório |
| `account_id` | bigint | obrigatório |
| `provider_event_id` | string | único por conexão quando externo |
| `event_type` | string | `payment_received`, etc. |
| `occurred_at` | datetime | obrigatório |
| `actor_id` | bigint | nulo para webhook |
| `metadata` | jsonb | nunca inclui chave ou cartão |
| `processing_status` | enum | `processed`, `ignored`, `failed` |

### FinanceWebhookDelivery

Registro técnico e reprocessável de webhook autenticado. O corpo original é armazenado somente para o servidor e não integra qualquer serialização pública.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` / `finance_provider_connection_id` | bigint | obrigatórios e com escopo de conta |
| `provider_event_id` | string | único por conexão quando o provedor o informar |
| `payload_digest` | string | SHA-256 único por conexão para deduplicar entrega sem ID |
| `raw_payload` | text | obrigatório; cifrado quando disponível; nunca serializado |
| `processing_status` | enum | `processed`, `ignored`, `failed` |
| `error_message` | text | somente classe sanitizada da falha |
| `received_at` / `processed_at` | datetime | auditoria operacional |
| `retry_count` | integer | incrementado por reprocessamento administrativo |

### FiscalInvoice

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatório |
| `payment_id` | bigint | opcional |
| `provider_invoice_id` | string | único por conexão |
| `status` | enum | `draft`, `created`, `synchronized`, `authorized`, `canceling`, `canceled`, `error` |
| `number` | string | após autorização |
| `validation_code` | string | após autorização |
| `pdf_url` / `xml_url` | text | após autorização |
| `error_message` | text | mensagem sanitizada |
| `issued_at` | datetime | opcional |

### FiscalProfile

Objeto P1, separado da conexão de pagamento. Só uma configuração fiscal ativa por conta/provedor pode emitir documentos.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` / `provider_connection_id` | bigint | obrigatórios, escopo de conta |
| `legal_name` / `tax_identifier` | string | obrigatório antes de emitir; dado mascarado fora da configuração |
| `address` / `municipality_code` | jsonb/string | obrigatório quando o provedor/país exigir |
| `default_service_code` / `default_description` | string | revisável antes de emitir |
| `document_series` | string | obrigatório somente quando aplicável |
| `status` | enum | `draft`, `verified`, `attention`, `invalid` |
| `verified_at` / `verified_by_id` | datetime/bigint | auditoria |

O perfil não autoriza emissão sozinho: o adaptador ainda valida capacidade do mercado, credenciais e dados exigidos pelo município/país.

### FormTemplate e FormTemplateVersion

`FormTemplate` é o objeto administrativo estável. Cada publicação cria uma `FormTemplateVersion` imutável com schema JSONB validado.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatório |
| `name` | string | obrigatório |
| `category` | enum | `lead_capture`, `pre_consultation`, `clinical`, `consent`, `other` |
| `active_version_id` | bigint | opcional |
| `access_classification` | enum | `commercial`, `restricted`, `sensitive_health` |
| `public_enabled` / `public_token` | boolean/string | publicação opt-in e token opaco único para link geral |
| `settings` | jsonb | idioma, descrição, `brand_name`, tema fechado (`calm`, `warm`, `contrast`) e URL externa opcional de logo; `brand_logo` é um anexo Active Storage PNG/JPEG/WebP até 2 MB; P1: `clinical_access` e `clinical_retention_days` |

`FormTemplateVersion.schema` contém seções, campos, validação, condicionais, mapeamento permitido e texto de consentimento. O schema não armazena HTML arbitrário. Cada campo pode declarar `help_text` simples, renderizado abaixo da pergunta e ligado ao controle por `aria-describedby`; não substitui o rótulo visível. Antes de publicar, o backend exige seções e chaves estáveis, impede chaves duplicadas entre seções e valida tipo, rótulo, opções de campos de seleção e formato de destino comercial. Links públicos comerciais exigem também o mapeamento de `name` e de `email` ou `phone_number` para chaves de perguntas publicadas; a mesma regra impede habilitar o link depois de uma versão privada já existir. Tipos iniciais: texto curto/longo, e-mail, telefone, número, moeda, data/data-hora, seleção simples/múltipla, checkbox, consentimento, aceite por nome digitado e campo oculto. O tipo `attachment` só é permitido em `sensitive_health`: aceita PDF, JPG, PNG, HEIC ou HEIF, no máximo 10 MB por arquivo e cinco arquivos por submissão. O aceite por nome digitado registra a manifestação no formulário, mas não é apresentado como assinatura eletrônica qualificada ou evidência jurídica autônoma. O P0 aceita `crm_mapping.contact`: o destino é `name`, `email`, `phone_number` ou um atributo em `custom_attributes`, e o valor é uma chave de resposta publicada. Em `pt_BR` e `pt_PT`, a submissão normaliza telefones nacionais reconhecíveis para E.164 antes de deduplicar/criar ou atualizar o contato; nos demais idiomas somente E.164 explícito é aceito. O P1 inicial aceita `crm_mapping.kanban_card.custom_field_values`, em que cada chave é um campo personalizado do card e cada valor é uma chave de resposta publicada. Ele exige destino comercial, só aceita campos existentes do board de destino e nunca aceita fórmulas. Na submissão, o card é bloqueado, valores já existentes são preservados e o próprio `KanbanCard` normaliza e valida tipo/opções; mapeamento inválido é registrado como rejeitado sem descartar a resposta. `crm_destination` declara `kanban_board_id`, `kanban_stage_id`, `inbox_id` e política `reuse_open` ou `create_new`; o serviço confirma escopo/estado na conta no momento da submissão. Todas essas configurações são removidas do payload público. Para `sensitive_health`, a publicação exige criptografia configurada, pelo menos um consentimento obrigatório e ausência total de `crm_mapping` e `crm_destination`.

No envio, o servidor valida a mesma condição usada pela interface e só persiste respostas de perguntas visíveis e não técnicas. Campo `hidden`, resposta de uma condicional que não foi apresentada e chave enviada fora do schema nunca entram em `FormSubmission`, no mapeamento de contato ou no destino comercial.

O editor é uma superfície visual de três áreas: estrutura de etapas e perguntas à esquerda, prévia segura e clicável do formulário ao centro, e propriedades essenciais da seleção à direita. A prévia nunca grava respostas e mostra imediatamente título, ajuda, obrigatoriedade, tipos e opções da pergunta selecionada. Clicar em uma etapa ou pergunta seleciona o item equivalente na estrutura; criar pergunta ou inserir bloco mantém a seleção no item novo. Identificadores, mapeamentos CRM, condicionais, publicação e destino ficam recolhidos em `Configurações avançadas`, preservando o fluxo diário de uma secretaria sem ocultar controles de configuração.

A prévia aceita respostas efêmeras para testar `visible_when`, possui alternância desktop/celular e pode ser limpa sem alterar o schema. A estrutura usa `vuedraggable` já presente no dashboard para reordenar etapas e perguntas; os controles acessíveis de mover acima/abaixo permanecem nas configurações avançadas como alternativa ao arrastar. O inspector visual permite criar por tipo, duplicar e remover pergunta. Nenhum gesto de arrastar é a única forma de concluir uma ação.

Cada edição não publicada é serializada no `localStorage` do navegador, por `form_template_id`, sem respostas de pacientes, tokens ou submissões. Ao reabrir um template, somente um rascunho mais recente que o `updated_at` do servidor é recuperado; a pessoa pode descartá-lo. `beforeunload` avisa sobre alterações não publicadas. Publicar remove o rascunho local e continua usando `FormTemplate#publish!`, que gera uma versão imutável. A checklist de publicação é apenas orientação local; o `Forms::SchemaValidator` permanece a fonte de verdade no backend.

`settings.brand_logo_url` é opcional. `Forms::PublicPayloadBuilder` só expõe URL absoluta HTTP(S), com no máximo 2048 caracteres; qualquer valor inválido fica ausente do payload público. Um administrador também pode enviar uma logo PNG, JPEG ou WebP de até 2 MB diretamente no template. A imagem anexada tem prioridade sobre a URL externa e usa uma URL gerenciada pelo Active Storage; o formulário público mantém a inicial da marca como fallback. Um formulário comercial público pode definir `captcha_provider: turnstile` e `captcha_site_key`; a chave secreta vem exclusivamente de `RAEVO_TURNSTILE_SECRET_KEY`, e a submissão chama a verificação do Cloudflare no servidor antes de persistir qualquer resposta. A resposta detalhada retorna `section_title` por campo permitido, para o dashboard agrupar a leitura por etapa; para formulários clínicos, esse payload continua sujeito à policy e ao registro em `FormAccessAudit`.

O editor disponibiliza blocos comerciais locais e editáveis para inserir dados de contato, preferência de agenda e origem/interesse. Cada inserção cria seção e campos próprios no schema da versão, resolve chaves duplicadas com sufixo estável e não introduz informações clínicas. Administradores também podem salvar uma seção comercial como bloco reutilizável da conta e inseri-la em outro modelo; o servidor valida o mesmo schema da seção, mantém o bloco no escopo da conta e a inserção sempre gera novas chaves. Esses blocos não levam mapeamento CRM, condições, respostas, destino, token ou qualquer informação de saúde. Seções aceitam `description` textual curta; a descrição vazia não é publicada. A ordem de seções e perguntas pode ser alterada por botões acessíveis de mover acima/abaixo, preservando chave, descrição e configurações do item. Blocos clínicos compartilhados dependem das permissões e retenção do P1 clínico.

### FormFieldGroup

`FormFieldGroup` é uma biblioteca administrativa reutilizável, delimitada por conta, para uma seção comercial do formulário.

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatório; todo acesso é escopado à conta atual |
| `name` | string | obrigatório, até 120 caracteres e único por conta |
| `section` | jsonb | seção validada com `key`, título/descrição opcionais e perguntas permitidas |

Somente administrador cria, lista ou remove blocos. O bloco não é uma referência viva dentro de um formulário: ao inseri-lo, o editor cria uma cópia com identificadores novos, evitando alteração retroativa em versões já publicadas.

`POST /api/v1/accounts/:account_id/forms/templates/:id/duplicate` é restrito a administrador. Ele recebe novo `name` e `slug`, cria outro `FormTemplate` privado e replica apenas categoria, classificação, configurações e schema da versão ativa como uma versão independente. Não copia submissões, convites, token/link público nem altera o modelo de origem.

Quando uma submissão comercial fica vinculada a uma oportunidade, `Forms::SubmissionEventDispatcher` publica `forms.submission.completed` com `account_id`, `board_id`, `card_id`, `form_submission_id`, `form_template_id` e chave idempotente. O `KanbanCardListener` encaminha o evento às regras ativas daquele board. Respostas, metadados, token de convite e qualquer conteúdo clínico não entram no evento nem no histórico de execução.

### FormInvitation

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatório |
| `form_template_version_id` | bigint | obrigatório |
| `contact_id` / `kanban_card_id` | bigint | contexto opcional/individual |
| `token_digest` | string | hash de token aleatório; único |
| `expires_at` | datetime | opcional |
| `max_uses` / `uses_count` | integer | consumo transacional |
| `status` | enum | `active`, `expired`, `consumed`, `revoked` |
| `sent_at` / `completed_at` | datetime | auditoria |

### FormSubmission

| Campo | Tipo | Regra |
| --- | --- | --- |
| `account_id` | bigint | obrigatório |
| `form_template_version_id` | bigint | obrigatório |
| `form_invitation_id` | bigint | opcional |
| `contact_id` / `kanban_card_id` | bigint | após resolução |
| `status` | enum | P0 comercial: `submitted`, `discarded` |
| `answers` | jsonb | respostas comerciais permitidas pelo schema; fica vazio para `sensitive_health` |
| `sensitive_answers_ciphertext` | text | respostas de `sensitive_health` cifradas; nunca serializadas em listagens ou eventos |
| `metadata` | jsonb | P0 comercial: metadados minimizados; não recebe contexto de CRM no payload público |
| `submitted_at` | datetime | obrigatório |
| `form_invitation_id` | bigint | opcional; identifica submissão individual sem expor token |

`FormAccessAudit` registra `account_id`, `form_submission_id`, `actor_id`, ação `view`, `attachment_view`, `export` ou `retention_discarded` e horário, sem copiar conteúdo clínico. `FormSubmission` possui anexos clínicos privados por Active Storage apenas para submissões sensíveis; o detalhe autorizado retorna somente `id`, nome, MIME e tamanho, nunca URL. O download passa por rota autenticada e cria a auditoria `attachment_view`. A exportação JSON exige administrador, omite anexos e cria a auditoria `export`. O detalhe autorizado também deriva um snapshot de consentimento a partir da versão imutável e da resposta cifrada: chave, texto aceito, tipo de aceite, manifestação e horário da submissão. Ele não constitui assinatura eletrônica qualificada e desaparece quando a retenção descarta a resposta. Para administradores, o mesmo detalhe retorna a trilha de acessos sanitizada com ação, ator e horário; profissionais autorizados não recebem essa trilha. O P1 clínico entrega armazenamento separado, convite individual de uso único, consentimento e auditoria. `FormTemplate.settings.clinical_access` contém apenas `user_ids` e `team_ids` da mesma conta; administradores sempre têm acesso, e agentes só recebem respostas de anamneses que os incluam diretamente ou por equipe. `clinical_retention_days` é opcional e só vale para modelo `sensitive_health`: vazio significa preservação; prazo positivo agenda uma verificação diária distribuída. Ao vencer, o serviço remove anexos, respostas cifradas e metadados, marca a submissão como `discarded` e grava `retention_discarded`; não apaga contato, oportunidade, versão nem auditoria. O escopo da API filtra também a lista para não expor resumos de outros formulários. Índice não sensível e varredura antimalware dependem da próxima etapa clínica.

## APIs internas

Todas exigem autenticação e policy de conta, exceto rotas públicas de formulário.

### Financeiro

| Método | Rota | Uso |
| --- | --- | --- |
| `GET` | `/api/v1/accounts/:account_id/finance/provider_connections` | conexões mascaradas disponíveis no mercado |
| `POST` | `/api/v1/accounts/:account_id/finance/provider_connections` | conectar provedor compatível |
| `PATCH` | `/api/v1/accounts/:account_id/finance/provider_connections/:id` | trocar chave/configuração |
| `DELETE` | `/api/v1/accounts/:account_id/finance/provider_connections/:id` | desconectar |
| `POST` | `/api/v1/accounts/:account_id/finance/provider_connections/:id/verify` | validar a conexão no servidor |
| `GET` | `/api/v1/accounts/:account_id/finance/payments` | lista/relatórios básicos |
| `GET` | `/api/v1/accounts/:account_id/finance/payments/summary` | totais por estado e moeda |
| `POST` | `/api/v1/accounts/:account_id/finance/payments` | criar cobrança |
| `GET` | `/api/v1/accounts/:account_id/finance/payments/:id` | detalhe e histórico |
| `cliente` | composer existente | prepara o link no rascunho da conversa vinculada, sem envio automático |
| `POST` | `/api/v1/accounts/:account_id/finance/payments/:id/cancel` | cancela cobrança pendente/vencida conforme o provedor |
| `POST` | `/api/v1/accounts/:account_id/finance/payments/:id/mark_received` | confirma recebimento de cobrança manual elegível |
| `POST` | `/api/v1/accounts/:account_id/finance/payments/:id/refund` | solicita estorno total Asaas elegível; webhook confirma estado final |
| `GET` | `/api/v1/accounts/:account_id/finance/provider_connections/:id/webhook_deliveries` | lista metadados sanitizados das últimas entregas |
| `POST` | `/api/v1/accounts/:account_id/finance/provider_connections/:id/webhook_deliveries/:id/retry` | reprocessa entrega com falha, sem devolver o corpo original |
| `POST` | `/api/v1/accounts/:account_id/fiscal_invoices` | P1 |

| `GET/PATCH` | `/api/v1/accounts/:account_id/finance/module` | estado/mercado/provedor padrão; desligamento exige `confirm_disable=true` |

Toda rota financeira chama `Finance::ModuleAccessPolicy` antes da policy específica. Quando desligado, responde `404` para recursos da interface e `403` para tentativa de operação autenticada, sem oferecer estado parcial.

### Formulários administrativos

| Método | Rota | Uso |
| --- | --- | --- |
| `GET/POST` | `/api/v1/accounts/:account_id/forms/templates` | lista/cria |
| `GET/PATCH` | `/api/v1/accounts/:account_id/forms/templates/:id` | edita metadados |
| `POST/DELETE` | `/api/v1/accounts/:account_id/forms/templates/:id/logo` | envia/remove logo administrada; remover restaura a URL externa ou a inicial da marca |
| `GET/POST` | `/api/v1/accounts/:account_id/forms/field_groups` | lista/cria blocos reutilizáveis comerciais da conta |
| `DELETE` | `/api/v1/accounts/:account_id/forms/field_groups/:id` | remove um bloco que não afeta modelos já publicados |
| `POST` | `/api/v1/accounts/:account_id/forms/templates/:id/publish` | cria versão e publica |
| `GET` | `/api/v1/accounts/:account_id/forms/templates/:id/versions` | histórico administrativo sanitizado, sem schema |
| `POST` | `/api/v1/accounts/:account_id/forms/templates/:id/invitations` | convite individual |
| `GET` | `/api/v1/accounts/:account_id/forms/submissions` | lista resumida por policy |
| `GET` | `/api/v1/accounts/:account_id/forms/submissions/:id` | resposta autorizada |
| `GET` | `/api/v1/accounts/:account_id/forms/submissions/:id/export` | exportação JSON auditada, somente administrador, sem anexos |
| `GET` | `/api/v1/accounts/:account_id/forms/submissions/:id/attachments/:attachment_id` | download clínico autenticado e auditado |
| `GET` | `/api/v1/accounts/:account_id/forms/kanban_cards/:kanban_card_id` | resumos de convites e respostas da oportunidade, sem token ou respostas |

### Formulários públicos

| Método | Rota | Uso |
| --- | --- | --- |
| `GET` | `/formularios/convites/:token` | convite individual publicado |
| `POST` | `/formularios/convites/:token/respostas` | envio público do convite |
| `GET` | `/formularios/:public_token` | link público geral de modelo comercial |
| `POST` | `/formularios/:public_token/respostas` | envio público geral |

Respostas de erro público não revelam se contato, oportunidade ou convite existe. Links usam token opaco e tokens individuais são armazenados apenas como digest.

## Webhooks

### Entrada Asaas

`POST /webhooks/asaas/:account_token`

Processamento:

1. Localizar a conexão pela rota/token e validar cabeçalho Asaas configurado.
2. Validar payload e normalizar evento.
3. Deduplicar por `provider_event_id` ou chave estável derivada de evento/pagamento/data.
4. Persistir `PaymentEvent` em transação.
5. Atualizar `Payment`/`FiscalInvoice` somente se a transição de estado for válida.
6. Após commit, publicar evento de domínio e enfileirar notificações/automação.
7. Responder `2xx` somente após persistir; falha transitória retorna erro para permitir reentrega.

Eventos P0 de cobrança: `PAYMENT_CREATED`, `PAYMENT_OVERDUE`, `PAYMENT_CONFIRMED`, `PAYMENT_RECEIVED`, `PAYMENT_REFUNDED`, eventos de chargeback e cancelamento quando aplicáveis.

Eventos P1 de NF: `INVOICE_CREATED`, `INVOICE_UPDATED`, `INVOICE_SYNCHRONIZED`, `INVOICE_AUTHORIZED`, `INVOICE_CANCELED`, `INVOICE_ERROR`.

### Eventos de domínio publicados

- `finance.payment.created`
- `finance.payment.overdue`
- `finance.payment.confirmed`
- `finance.payment.received`
- `finance.payment.refunded`
- `finance.payment.chargeback`
- `finance.invoice.authorized`
- `finance.invoice.error`
- `forms.submission.completed` está disponível para Vue Flow quando a submissão estiver vinculada a uma oportunidade; seu contexto contém somente IDs permitidos, sem respostas. Eventos de convite enviado, início, abandono, resposta crítica e prazo expirado permanecem P1.

O Vue Flow recebe uma projeção segura dos eventos. Campos clínicos nunca entram no contexto padrão do nó; uma permissão futura e uma allowlist por automação são necessárias para isso.

## Serviços e jobs

| Classe | Responsabilidade |
| --- | --- |
| `Finance::Asaas::VerifyConnectionService` | testa chave e atualiza estado sem vazar segredo |
| `Finance::Asaas::UpsertCustomerService` | cria/localiza cliente e persiste referência por contato |
| `Finance::Asaas::CreatePaymentService` | cria cobrança e Payment local em transação lógica |
| `Finance::Asaas::ProcessWebhookService` | valida, deduplica e aplica evento |
| `Finance::WebhookDeliveryRecorder` | preserva entrega autenticada sem expor o corpo ao dashboard |
| `Finance::Asaas::RetryWebhookDeliveryService` | reprocessa entrega com falha sob lock da entrega |
| `Finance::PaymentCreatedEventService` | registra e publica a criação local sem depender do webhook |
| `Finance::MarkOverduePaymentsJob` | marca cobranças manuais abertas como vencidas após a data e publica um único evento |
| `Finance::Asaas::RefundPaymentService` | solicita estorno total elegível sem antecipar o estado financeiro |
| `Finance::Asaas::IssueInvoiceService` | P1, emite NF |
| `Finance::Asaas::ProcessInvoiceWebhookService` | P1, sincroniza NF |
| `Forms::PublishTemplateService` | valida schema e cria versão imutável |
| `Forms::CreateInvitationService` | emite token/convite com contexto |
| `Forms::SubmitPublicFormService` | valida, persiste submissão, consome o convite e aplica somente os mapeamentos declarados de contato e oportunidade |
| `Forms::MapSubmissionToCrmService` | atualiza somente atributos de contato declarados |
| `Forms::CreatePublicOpportunityService` | cria ou reaproveita oportunidade somente no destino comercial validado |
| `Forms::AccessAuditService` | registra leitura/exportação sem gravar conteúdo sensível |

Contrato do adaptador financeiro:

| Método | Retorno mínimo |
| --- | --- |
| `verify_connection` | estado, identidade exibível e capacidades |
| `upsert_customer` | `provider_customer_id` |
| `create_payment` | ID externo, URL/fatura, status e métodos; timeout é conciliado por `externalReference` antes de falhar |
| `cancel_payment` / `refund_payment` | P1, estado normalizado |
| `parse_webhook` | evento normalizado, chave idempotente e assinatura válida |
| `issue_invoice` | P1, referência fiscal e estado |

Asaas, Easypay, ifthenpay e Moloni implementam somente as capacidades que possuem. O controller não contém condicionais por provedor.

Jobs: entrega de mensagem, reprocessamento de webhook com falha, expiração de convite, lembrete de formulário, emissão fiscal e automações pós-commit.

## Policies e segurança

- `Finance::PaymentPolicy`: administrador financeiro e permissões explícitas para criar, cancelar, estornar, emitir NF e consultar relatórios.
- `Finance::AsaasConnectionPolicy`: somente administrador da conta.
- `Forms::TemplatePolicy`: administrador/configurador.
- `Forms::SubmissionPolicy`: administrador lê todas as respostas. Agente só lê submissão `sensitive_health` quando o formulário o inclui por `clinical_access.user_ids` ou por membro de uma equipe em `clinical_access.team_ids`; a scope da listagem aplica a mesma regra. A configuração é validada contra a própria conta e não permite referências externas.
- Toda busca aplica `account_id` no escopo antes de carregar ID externo ou interno.
- Segredos cifrados com mecanismo de credencial/encriptação existente; serializadores retornam somente máscara e metadados.
- Logs estruturados usam IDs e estados, nunca conteúdo de respostas, chave, QR Code completo, token ou dados de cartão.
- Arquivos P1: allowlist MIME/extensão, limite de tamanho, armazenamento privado e autorização por download em rota autenticada auditada. O dashboard nunca recebe URL pública ou assinada; retenção configurável é opt-in e auditada, enquanto varredura antimalware permanece pré-requisito antes de escalar anexos clínicos.

## Regras de consistência

- Não criar novo cliente Asaas quando já houver `provider_customer_id` do mesmo contato e conexão; se não existir, procurar/criar de forma controlada.
- `external_reference` deve incluir identificador local imutável de pagamento, não nome/telefone.
- Eventos podem chegar repetidos ou fora de ordem; a máquina de estados atualiza apenas transições válidas e registra o restante como `ignored`, sem disparar automação.
- O webhook de uma cobrança pendente continua sendo recebido mesmo se `FinanceModuleSetting.enabled=false`; esse estado bloqueia novas ações e UI, não perde a liquidação de uma obrigação já criada. Desconectar a conexão é uma operação distinta, bloqueada enquanto houver pagamentos não terminais sem confirmação administrativa de impacto.
- Reconciliação é dirigida, não polling amplo: consulta somente pagamentos com estado antigo, divergência explícita ou conexão em `attention`, usando `external_reference`/ID externo. Ela nunca chama `create_payment` e só publica evento quando a transição local for efetivamente alterada.
- O endpoint de webhook valida `asaas-access-token`, persiste a entrega e responde 2xx antes do processamento pesado assíncrono. A chave da API Asaas nunca é usada como token do webhook. A saúde da conexão monitora repetição de falhas, fila interrompida e a última entrega, respeitando o período de retenção que o provedor disponibiliza.
- Comunicação financeira é opt-in por automação: a execução persiste `payment_id`, canal e mensagem associada. Esperas e reexecuções não podem substituir o pagamento por outra cobrança do contato.
- Formulário público não pode escolher livremente `account_id`, `contact_id` ou `kanban_card_id`; esses valores vêm do link/contexto ou da política de resolução.
- O destino de oportunidade é validado por conta, funil ativo, etapa ativa, caixa permitida e política declarada; falha de destino registra estado sanitizado na submissão sem apagá-la. O mapeamento declarado para campos personalizados só pode atingir definições existentes do mesmo board, não pode escrever fórmula e é aplicado sob bloqueio do card, preservando valores existentes; erro de valor é sanitizado como `rejected` na submissão, sem apagá-la.
- Formulários classificados como `sensitive_health` não podem ter link público geral, CRM mapping, destino comercial, campos no card compacto, etiquetas, preview de conversa, payload padrão de webhook ou evento de automação. A leitura detalhada só acontece pela API autorizada e cria `FormAccessAudit`.

## Testes e aceite técnico

### Financeiro

- request specs para todas as rotas, escopo de conta e permissões;
- request specs para módulo desativado, mercado incompatível e adaptador não liberado;
- service specs para transições de estado, deduplicação e reentrega;
- teste de webhook repetido e fora de ordem;
- teste de segredo ausente do JSON, log e serializador;
- teste de falha/timeout Asaas sem duplicar cobrança local;
- teste de valor parcialmente recebido/divergente, moeda e conversão de data no fuso da conta;
- teste de módulo desativado e conexão desconectada com cobrança pendente, garantindo que webhook válido não se perca;
- teste de reconciliação que consulta pagamento existente e nunca recria cobrança;
- E2E: conectar conta simulada, criar cobrança, enviar link, receber webhook e ver status no card.

### Formulários

- schema validation por tipo, condicional e obrigatoriedade;
- teste de token expirado, revogado, esgotado e adulterado;
- teste de deduplicação por e-mail/telefone e de política da oportunidade;
- teste de versão imutável;
- matriz de autorização: secretaria, agente, profissional, administrador e conta errada;
- E2E: abrir formulário público, submeter, criar/vincular contato e oportunidade, conferir apenas campos permitidos no CRM;
- acessibilidade: rótulos, erro por campo, foco, leitura por leitor de tela e navegação por teclado.
- anamnese: ausência de chave de criptografia impede publicação; consentimento é obrigatório; convite sem contato ou com mais de um uso é rejeitado; respostas não aparecem em `answers`, resumo, automação ou CRM; leitura autorizada registra auditoria.

## Migração e rollout

1. Entregar `FinanceModuleSetting`, catálogo de adaptadores, policies e feature flag por conta sem UI pública.
2. Habilitar sandbox para conta interna e rodar eventos simulados.
3. Liberar Financeiro P0 a um cliente piloto, com monitoramento de falhas de webhook.
4. Liberar Formulários comerciais a um cliente piloto com formulário de captação.
5. Antes de liberar anamnese, executar as migrations clínicas, configurar `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` no ambiente, validar convite individual e auditoria, e revisar acesso, contrato/LGPD e retenção com a clínica.

Não há migration ou deploy associado a este documento. Cada P0 deve trazer migrations, índice, policy, testes e plano de reversão no PR correspondente.
