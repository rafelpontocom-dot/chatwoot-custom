# Spec: Raevo Marketing

## Progresso atual

Entregue: `MarketingModuleSetting`, `MarketingTouchpoint`, `MarketingIntakeSource`,
`MarketingProviderConnection`, `MarketingLeadForm`, `MarketingWebhookDelivery`,
os serviços de captação, a API pública de entrada, a conexão Meta e a recepção
de leadgen, mais os jobs horários.

## Fronteira técnica

A atribuição por lead é nossa e não vem de ferramenta nenhuma: o Reportei sabe
quanto se gastou, nunca que *esta* conversa veio *daquele* anúncio.

O que **não** se reimplementa: a criação de oportunidade respeita
`crm_destination` e a política `reuse_open`, o mesmo contrato do Forms. Um
formulário do Meta e uma landing page são o mesmo conceito — um lugar
configurado de onde vem lead, com destino próprio — e por isso entram pelo
mesmo `Marketing::IngestLeadService`.

`kanban_cards.origin` continua com dois valores e significa *como* o card
nasceu, não de onde veio o lead. A origem vive em `origem_do_lead`.

## Modelo de dados

Três camadas, cada uma com um papel:

| Camada | Onde | Papel |
| --- | --- | --- |
| Toque | `marketing_touchpoints` | Fonte da verdade. FKs anulam: apagar card ou conversa não apaga a história |
| Contato | `contacts.additional_attributes['marketing_attribution']` | `first_touch` (escrita única) e `last_touch`; leitura barata para o carimbo |
| Oportunidade | `kanban_cards.custom_field_values` | A aba Marketing. Congela o que era verdade quando o card nasceu |

O congelamento no card é deliberado: sem ele, o relatório do trimestre passado
muda sozinho quando o paciente clica num anúncio novo.

Demais tabelas: `marketing_module_settings` (opt-in),
`marketing_intake_sources` (uma por origem, token cifrado),
`marketing_provider_connections` (único por conta+plataforma+id externo — conta
de anúncio é muitos-por-plataforma, ao contrário do Financeiro),
`marketing_lead_forms`, `marketing_webhook_deliveries` (idempotência).

## APIs internas

```
GET|PATCH /api/v1/accounts/:id/marketing/module
GET       /api/v1/accounts/:id/marketing/touchpoints[/summary]
          /marketing/intake_sources        (index, create, update, destroy, rotate)
          /marketing/connections           (index, destroy, authorization_url,
                                            sync_pages, subscribe_page, sync_lead_forms)
GET|PATCH /marketing/lead_forms
```

Todos exigem o módulo ativo (403 caso contrário) e passam por policy. Nenhum
serializador expõe token: `public_payload` do modelo é a única saída, e o token
da origem de entrada só aparece na criação e na rotação.

## APIs públicas

```
GET  /public/api/v1/marketing/intake/schema   catálogo dos campos aceitos
POST /public/api/v1/marketing/intake          cria contato + oportunidade
```

Autenticação por `X-Raevo-Intake-Token` em **header**, nunca na URL — URL vaza
por `Referer`, log de proxy e histórico de browser. Token inválido, origem
desligada e conta sem módulo respondem igual: não se confirma a existência de
uma porta para quem não tem a chave.

Idempotência obrigatória: `idempotency_key` do cliente ou digest do corpo.
Limite por token, não por IP — o n8n de um cliente sai sempre do mesmo IP e uma
landing movimentada sai de milhares.

## Webhooks

```
GET  /webhooks/marketing/meta   handshake, ecoa hub.challenge
POST /webhooks/marketing/meta   leadgen
```

O Meta assina com **`X-Hub-Signature-256` usando o app secret**, não com token
nosso no caminho: por isso este receptor só se parece com o do Financeiro no
formato de gravar-depois-processar.

Qualquer payload com assinatura válida recebe **200**, inclusive evento de
formulário desconhecido — um 4xx faria o Meta reentregar para sempre algo que
nunca foi nosso.

O webhook **não traz o lead**, traz um `leadgen_id`. A busca vai para um job
porque o Meta exige resposta em menos de 20s.

## Serviços e jobs

```
Marketing::AttributionFields          lista branca; CARD_KEYS e CONTACT_ONLY_KEYS
Marketing::UrlAttributionParser       query string → atribuição
Marketing::DeriveLeadOriginService    origem_do_lead / sub_origem
Marketing::RecordTouchpointService    única porta de escrita; verifica o opt-in
Marketing::StampCardAttributionService  carimba o card, nunca por cima
Marketing::CreateLeadOpportunityService  oportunidade sem usuário
Marketing::IngestLeadService          contato + oportunidade + toque + carimbo
Marketing::Meta::*                    OAuth, Graph, páginas, formulários, leadgen
```

Jobs no `Internal::TriggerHourlyScheduledItemsJob`, **sem cron novo**:
`FlagExpiringConnectionsJob` (o Meta não emite refresh token; avisa uma semana
antes) e `SyncLeadFormsSchedulerJob` (ordena por obsolescência, pula conexões em
`attention`, teto de `Limits::BULK_EXTERNAL_HTTP_CALLS_LIMIT`).

## Policies e segurança

Duas permissões: `marketing_view` e `marketing_configure`, em sincronia entre
`enterprise/app/models/custom_role.rb`, `constants/permissions.js`,
`customRole.json` nos três locales e as policies.

Segredos cifrados com `encrypts … if Chatwoot.encryption_configured?`. O token
de página do Meta fica **em cache, não no banco**: recupera-se a qualquer
momento com o token do usuário, e o que não é guardado não vaza. Só o
`PageTokenService` o lê.

Erro de provedor guarda **a classe, nunca o texto** — a mensagem do Meta pode
carregar id de conta alheia.

## Regras de consistência

- Carimbo nunca sobrepõe valor não vazio.
- `first_touch` escreve uma vez.
- Chave que o quadro não configurou é descartada pelo próprio `KanbanCard`, o
  que torna o carimbo seguro num quadro sem o preset.
- Toque duplicado colapsa por `dedupe_digest` único por conta.
- Serviços de captação retornam cedo se o módulo estiver desligado.

## Testes e aceite técnico

103 exemplos de RSpec, só do módulo, cobrem: lista branca e truncamento, derivação de origem
nos quatro casos, opt-in, idempotência, abuso do endpoint público (token
ausente, inválido, revogado, limite, corpo repetido), assinatura do webhook,
reentrega, formulário desconhecido, e expiração de token.

Antes de enviar: `bundle exec rubocop`, `pnpm test`, `pnpm raevo:design`,
`pnpm raevo:palette`, e **carregar o schema num banco vazio**
(`RAILS_ENV=test rails db:drop db:create db:schema:load`) — um schema montado à
mão já passou com chave estrangeira duplicada.

## Migração e rollout

Migrações `20260903100000` a `20260903150000`. A de `fbclid` e a dos click ids
do iOS são reversíveis; as de criação de tabela são aditivas.

Ordem para ligar numa conta:

1. Ativar o módulo em Marketing → engrenagem.
2. Criar as origens de entrada e repontar a landing para o `POST /intake`.
3. Preencher `MARKETING_META_*` no Super Admin (app Meta **separado** — o
   Messenger já ocupa o callback do `FB_APP_ID`).
4. Conectar o Meta, assinar as páginas, carregar e mapear os formulários.
5. Desligar os workflows de n8n equivalentes, um a um, conferindo a taxa de
   captação entre cada um.
