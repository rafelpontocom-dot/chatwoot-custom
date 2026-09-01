require 'rails_helper'

RSpec.describe FormSubmissionPolicy, type: :policy do
  subject(:form_submission_policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:allowed_agent) { create(:user, account: account, role: :agent) }
  let(:team_agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:template) do
    FormTemplate.new(
      account: account,
      access_classification: 'sensitive_health',
      name: 'Anamnese',
      slug: 'anamnese',
      settings: { 'clinical_access' => { 'user_ids' => [allowed_agent.id], 'team_ids' => [team.id] } }
    )
  end
  let(:version) { FormTemplateVersion.new(account: account, form_template: template) }
  let(:submission) { FormSubmission.new(account: account, form_template_version: version) }

  let(:administrator_context) do
    { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) }
  end
  let(:allowed_agent_context) do
    { user: allowed_agent, account: account, account_user: allowed_agent.account_users.find_by(account: account) }
  end
  let(:team_agent_context) do
    { user: team_agent, account: account, account_user: team_agent.account_users.find_by(account: account) }
  end
  let(:other_agent_context) do
    { user: other_agent, account: account, account_user: other_agent.account_users.find_by(account: account) }
  end

  before { create(:team_member, team: team, user: team_agent) }

  permissions :show? do
    it 'allows an administrator to read a sensitive submission' do
      expect(form_submission_policy).to permit(administrator_context, submission)
    end

    it 'allows an explicitly authorized professional to read a sensitive submission' do
      expect(form_submission_policy).to permit(allowed_agent_context, submission)
    end

    it 'allows a member of an authorized team to read a sensitive submission' do
      expect(form_submission_policy).to permit(team_agent_context, submission)
    end

    it 'denies an agent that is not in the clinical access list' do
      expect(form_submission_policy).not_to permit(other_agent_context, submission)
    end

    it 'denies a submission from another account even to an administrator' do
      other_account = create(:account)
      other_template = FormTemplate.new(
        account: other_account,
        access_classification: 'sensitive_health',
        name: 'Anamnese externa',
        slug: 'anamnese-externa'
      )
      other_version = FormTemplateVersion.new(
        account: other_account,
        form_template: other_template
      )
      other_submission = FormSubmission.new(
        account: other_account,
        form_template_version: other_version
      )

      expect(form_submission_policy).not_to permit(administrator_context, other_submission)
    end
  end

  permissions :export? do
    it 'allows only an administrator to export a sensitive submission' do
      expect(form_submission_policy).to permit(administrator_context, submission)
      expect(form_submission_policy).not_to permit(allowed_agent_context, submission)
    end
  end

  # A regra do produto para formulário comercial: respostas são de
  # administração. Um agente atende conversas, não lê fichas de pacientes.
  describe 'a commercial submission' do
    let(:commercial_submission) do
      commercial = FormTemplate.new(account: account, access_classification: 'commercial',
                                    name: 'Pré-consulta', slug: 'pre-consulta')
      FormSubmission.new(account: account,
                         form_template_version: FormTemplateVersion.new(account: account, form_template: commercial))
    end

    permissions :show?, :index?, :export? do
      it 'is readable by an administrator' do
        expect(form_submission_policy).to permit(administrator_context, commercial_submission)
      end

      it 'is out of reach for an agent, even one with clinical access elsewhere' do
        expect(form_submission_policy).not_to permit(allowed_agent_context, commercial_submission)
        expect(form_submission_policy).not_to permit(other_agent_context, commercial_submission)
      end
    end
  end
end
