require 'rails_helper'

RSpec.describe Internal::ReconcilePlanConfigService do
  describe '#perform' do
    let(:service) { described_class.new }

    context 'when pricing plan is community' do
      before do
        allow(ChatwootHub).to receive(:pricing_plan).and_return('community')
      end

      # RAEVO — `disable_branding` saiu do `premium_features.yml` por decisão do
      # Pedro em 24/10/2026, junto com `custom_roles`. O teste nativo afirmava
      # que ela era desligada; passa a afirmar que fica, que é o que o produto
      # faz agora. Mantém as outras, para o job continuar coberto.
      it 'disables the premium features for accounts' do
        account = create(:account)
        account.enable_features!('audit_logs', 'captain_integration', 'captain_integration_v2')
        account_with_captain = create(:account)
        account_with_captain.enable_features!('captain_integration', 'captain_integration_v2')
        service.perform
        expect(account.reload.enabled_features.keys).not_to include(
          'captain_integration', 'captain_integration_v2', 'audit_logs'
        )
        expect(account_with_captain.reload.enabled_features.keys).not_to include('captain_integration', 'captain_integration_v2')
      end

      # RAEVO — decisão do Pedro, 24/10/2026. `custom_roles` saiu do
      # `premium_features.yml`: o job diário não a pode voltar a desligar,
      # senão toda a função personalizada atribuída morre à meia-noite.
      it 'leaves custom roles and branding alone' do
        account = create(:account)
        account.enable_features!('custom_roles', 'disable_branding', 'audit_logs')

        service.perform

        expect(account.reload.enabled_features.keys).to include('custom_roles', 'disable_branding')
        expect(account.reload.enabled_features.keys).not_to include('audit_logs')
      end

      # RAEVO — estes exemplos criavam o `INSTALLATION_NAME` do zero. No CI o
      # passo da semente do smoke de navegação grava-o na mesma base, e o
      # `create` passou a rebentar com chave duplicada. Gravar por cima não
      # depende de quem correu antes.
      it 'creates a premium config reset warning if config was modified' do
        InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_NAME').update!(value: 'custom-name')
        service.perform
        expect(Redis::Alfred.get(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING)).to eq('true')
      end

      # RAEVO — este fork reescreveu o `premium_installation_config.yml` com a
      # nossa marca, e o teste continuou a comparar com «Chatwoot». Estava
      # vermelho desde então, por nossa causa.
      it 'will not create a premium config reset warning if config is not modified' do
        InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_NAME').update!(value: 'RAEVO CRM')
        service.perform
        expect(Redis::Alfred.get(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING)).to be_nil
      end

      it 'updates the premium configs to default' do
        InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_NAME').update!(value: 'custom-name')
        InstallationConfig.find_or_initialize_by(name: 'LOGO').update!(value: '/custom-path/logo.svg')
        service.perform
        expect(InstallationConfig.find_by(name: 'INSTALLATION_NAME').value).to eq('RAEVO CRM')
        expect(InstallationConfig.find_by(name: 'LOGO').value).to eq('/brand-assets/raevo-logo.svg')
      end
    end

    context 'when pricing plan is not community' do
      before do
        allow(ChatwootHub).to receive(:pricing_plan).and_return('enterprise')
      end

      it 'unset premium config warning on upgrade' do
        Redis::Alfred.set(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING, true)
        service.perform
        expect(Redis::Alfred.get(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING)).to be_nil
      end

      it 'does not disable the premium features for accounts' do
        account = create(:account)
        account.enable_features!('disable_branding', 'audit_logs', 'captain_integration', 'captain_integration_v2')
        account_with_captain = create(:account)
        account_with_captain.enable_features!('captain_integration', 'captain_integration_v2')
        disable_branding_account = create(:account)
        disable_branding_account.enable_features!('disable_branding')
        service.perform
        expect(account.reload.enabled_features.keys).to include(
          'captain_integration', 'captain_integration_v2', 'disable_branding', 'audit_logs'
        )
        expect(account_with_captain.reload.enabled_features.keys).to include('captain_integration', 'captain_integration_v2')
        expect(disable_branding_account.reload.enabled_features.keys).to include('disable_branding')
      end

      it 'does not update the LOGO config' do
        InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_NAME').update!(value: 'custom-name')
        InstallationConfig.find_or_initialize_by(name: 'LOGO').update!(value: '/custom-path/logo.svg')
        service.perform
        expect(InstallationConfig.find_by(name: 'INSTALLATION_NAME').value).to eq('custom-name')
        expect(InstallationConfig.find_by(name: 'LOGO').value).to eq('/custom-path/logo.svg')
      end
    end
  end
end
