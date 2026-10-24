require 'rails_helper'

# Os portões que decidem se uma funcionalidade paga do Chatwoot vive nesta
# instalação. São QUATRO, e falhar um deixa a coisa a meio sem dizer porquê —
# foi assim que «ligar Funções Personalizadas» durou um dia e depois voltou a
# ficar cinzento. Um upgrade do upstream traz as versões deles inteiras e leva
# tudo isto sem conflito nenhum; cada exemplo diz o que se perdia.
#
# A decisão de destravar é do Pedro, 24/10/2026, e está registada no
# `enterprise/config/premium_features.yml` e na auditoria.
RSpec.describe 'Raevo premium gates' do # rubocop:disable RSpec/DescribeClass
  def yaml(path) = YAML.safe_load(Rails.root.join(path).read, aliases: true)

  # Portão 1 — o job diário. `Internal::ReconcilePlanConfigService` corre à
  # meia-noite UTC e desliga tudo o que estiver nesta lista quando o plano é
  # `community`. O comportamento em si está coberto em
  # spec/enterprise/services/internal/reconcile_plan_config_service_spec.rb.
  it 'keeps custom roles and branding out of the nightly reset' do
    reset = yaml('enterprise/config/premium_features.yml')

    expect(reset).not_to include('custom_roles', 'disable_branding')
    # As outras continuam a ser desligadas: isto não é «abrir tudo».
    expect(reset).to include('audit_logs', 'sla', 'captain_integration')
  end

  # Portão 2 — o padrão das contas novas.
  it 'gives a new account custom roles and unbranded surfaces' do
    features = yaml('config/features.yml').index_by { |feature| feature['name'] }

    expect(features.dig('custom_roles', 'enabled')).to be(true)
    expect(features.dig('disable_branding', 'enabled')).to be(true)
  end

  # Portão 3 — a tela. A rota exigia instalação `cloud` ou `enterprise`; a
  # nossa é `community`, e sem isto a tela e a entrada do menu ficavam ocultas
  # mesmo com a funcionalidade ligada.
  it 'shows the custom roles screen on a community installation' do
    route = Rails.root.join(
      'app/javascript/dashboard/routes/dashboard/settings/customRoles/customRole.routes.js'
    ).read

    expect(route).to include('INSTALLATION_TYPES.COMMUNITY')
  end

  # Portão 4 — a caixa do Super Admin. Ficava `disabled` para tudo o que fosse
  # `premium: true`, e por isso era impossível ligar nas contas que já existem.
  # Cinzento deve dizer «é desfeito à noite», não «é pago».
  describe 'the Super Admin checkbox' do
    it 'greys out only what the nightly job really resets' do
      greyed = SuperAdmin::AccountFeaturesHelper.reconciled_premium_features

      expect(greyed).not_to include('custom_roles', 'disable_branding')
      expect(greyed).to include('audit_logs')
    end

    it 'is a shorter list than the paid label, and that is the point' do
      expect(SuperAdmin::AccountFeaturesHelper.reconciled_premium_features.size)
        .to be < SuperAdmin::AccountFeaturesHelper.account_premium_features.size
    end

    it 'asks the helper, not the paid label' do
      form = Rails.root.join(
        'enterprise/app/views/fields/account_features_field/_form.html.erb'
      ).read

      expect(form).to include('reconciled_premium_features')
    end
  end
end
