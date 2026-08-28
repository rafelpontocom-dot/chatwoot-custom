require 'rails_helper'

RSpec.describe FinanceModuleSettingPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:setting) { FinanceModuleSetting.new(account: account) }
  let(:admin_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }

  permissions :update?, :configure? do
    it 'allows only administrators' do
      expect(described_class).to permit(admin_context, setting)
      expect(described_class).not_to permit(agent_context, setting)
    end
  end

  permissions :show? do
    it 'lets every account member inspect finance availability' do
      expect(described_class).to permit(admin_context, setting)
      expect(described_class).to permit(agent_context, setting)
    end
  end

  permissions :view_payments?, :create_payments?, :manage_payments? do
    it 'lets every account member work with allowed payments' do
      [admin_context, agent_context].each do |context|
        expect(described_class).to permit(context, setting)
      end
    end
  end

  context 'when an agent has a custom role' do
    let(:custom_role) { create(:custom_role, account: account, permissions: ['finance_view']) }
    let(:custom_policy) { described_class.new(agent_context, setting) }

    before { agent_context[:account_user].update!(custom_role: custom_role) }

    it 'limits payment actions to the granted financial capability' do
      expect(custom_policy.view_payments?).to be(true)
      expect(custom_policy.create_payments?).to be(false)
      expect(custom_policy.manage_payments?).to be(false)
      expect(custom_policy.configure?).to be(false)
    end
  end
end
