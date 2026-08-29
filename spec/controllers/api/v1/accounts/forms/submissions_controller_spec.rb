require 'rails_helper'

RSpec.describe 'Form submissions API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
  let(:card) { create(:kanban_card, account: account, contact: contact) }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
  end
  let(:submission) do
    version = template.publish!(schema: schema)
    invitation = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform.invitation

    Forms::SubmitPublicFormService.new(invitation: invitation, answers: { 'nome' => 'Pedro Raevo' }).perform!
  end
  let(:submissions_path) { "/api/v1/accounts/#{account.id}/forms/submissions" }

  it 'lists safe submission summaries and exposes answers only in the authorized detail' do
    submission

    get submissions_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      include('id' => submission.id, 'form_name' => 'Pré-consulta', 'contact' => include('id' => contact.id))
    )
    expect(response.parsed_body.first).not_to have_key('answers')

    get "#{submissions_path}/#{submission.id}", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'id' => submission.id,
      'answers' => include('nome' => 'Pedro Raevo'),
      'fields' => include(
        'key' => 'nome',
        'label' => 'Nome',
        'type' => 'text',
        'section_title' => 'Identificação'
      )
    )
  end

  it 'records a clinical read and returns decrypted answers only in authorized detail' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese inicial',
        slug: 'anamnese-inicial',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      version = clinical_template.publish!(schema: clinical_schema)
      invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: version,
        contact: contact,
        kanban_card: card
      ).perform.invitation
      clinical_submission = Forms::SubmitPublicFormService.new(
        invitation: invitation,
        answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true }
      ).perform!

      expect do
        get "#{submissions_path}/#{clinical_submission.id}", headers: administrator.create_new_auth_token, as: :json
      end.to change(FormAccessAudit, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('answers', 'alergias')).to eq('Penicilina')
      consent_snapshot = response.parsed_body.fetch('consent_snapshot').first
      expect(consent_snapshot).to include(
        'key' => 'consentimento_clinico',
        'type' => 'consent',
        'value' => true
      )
      expect(Time.iso8601(consent_snapshot.fetch('recorded_at')).to_i).to eq(clinical_submission.submitted_at.to_i)
      expect(response.parsed_body.fetch('audit_trail')).to include(
        include('action' => 'view', 'actor' => include('id' => administrator.id, 'name' => administrator.name))
      )
      expect(FormAccessAudit.last).to have_attributes(
        account: account,
        form_submission: clinical_submission,
        actor: administrator,
        action: 'view'
      )
    end
  end

  it 'exports a clinical response for an administrator without exposing attachment files' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese para exportação',
        slug: 'anamnese-para-exportacao',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      version = clinical_template.publish!(schema: clinical_schema)
      invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: version,
        contact: contact,
        kanban_card: card
      ).perform.invitation
      clinical_submission = Forms::SubmitPublicFormService.new(
        invitation: invitation,
        answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true }
      ).perform!

      expect do
        get "#{submissions_path}/#{clinical_submission.id}/export",
            headers: administrator.create_new_auth_token,
            as: :json
      end.to change(FormAccessAudit, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'answers' => include('alergias' => 'Penicilina'),
        'form_name' => 'Anamnese para exportação'
      )
      expect(response.parsed_body).not_to have_key('attachments')
      expect(FormAccessAudit.last.action).to eq('export')
    end
  end

  it 'lets an authorized professional list only the clinical submissions granted to them' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      professional = create(:user, account: account, role: :agent)
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese da profissional',
        slug: 'anamnese-da-profissional',
        category: 'clinical',
        access_classification: 'sensitive_health',
        settings: { 'clinical_access' => { 'user_ids' => [professional.id] } }
      )
      version = clinical_template.publish!(schema: clinical_schema)
      invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: version,
        contact: contact,
        kanban_card: card
      ).perform.invitation
      clinical_submission = Forms::SubmitPublicFormService.new(
        invitation: invitation,
        answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true }
      ).perform!
      commercial_submission = submission

      get submissions_path, headers: professional.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to contain_exactly(include('id' => clinical_submission.id))

      get "#{submissions_path}/#{clinical_submission.id}", headers: professional.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).not_to have_key('audit_trail')

      get "#{submissions_path}/#{commercial_submission.id}", headers: professional.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  it 'lists clinical document metadata and audits an authenticated download' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese com documento',
        slug: 'anamnese-com-documento',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      version = clinical_template.publish!(schema: clinical_schema)
      invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: version,
        contact: contact,
        kanban_card: card
      ).perform.invitation
      clinical_submission = Forms::SubmitPublicFormService.new(
        invitation: invitation,
        answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true }
      ).perform!
      clinical_submission.clinical_attachments.attach(
        io: StringIO.new('%PDF-1.4 exame'),
        filename: 'exame.pdf',
        content_type: 'application/pdf'
      )
      attachment = clinical_submission.clinical_attachments.first

      get "#{submissions_path}/#{clinical_submission.id}", headers: administrator.create_new_auth_token, as: :json

      expect(response.parsed_body.fetch('attachments')).to include(
        include('id' => attachment.id, 'filename' => 'exame.pdf', 'content_type' => 'application/pdf')
      )
      expect(response.parsed_body.to_s).not_to include('url')

      expect do
        get "#{submissions_path}/#{clinical_submission.id}/attachments/#{attachment.id}",
            headers: administrator.create_new_auth_token
      end.to change(FormAccessAudit, :count).by(1)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('%PDF-1.4 exame')
      expect(FormAccessAudit.last.action).to eq('attachment_view')
    end
  end

  private

  def schema
    {
      'crm_destination' => crm_destination,
      'sections' => [
        {
          'key' => 'identificacao',
          'title' => 'Identificação',
          'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }]
        }
      ]
    }
  end

  def crm_destination
    {
      'kanban_board_id' => card.kanban_board_id,
      'kanban_stage_id' => card.kanban_stage_id,
      'inbox_id' => card.inbox_id,
      'opportunity_policy' => 'reuse_open'
    }
  end

  def clinical_schema
    {
      'sections' => [
        {
          'key' => 'saude',
          'fields' => [
            { 'key' => 'alergias', 'type' => 'textarea', 'label' => 'Alergias', 'required' => true },
            {
              'key' => 'consentimento_clinico',
              'type' => 'consent',
              'label' => 'Autorizo o tratamento dos dados de saúde para atendimento',
              'required' => true
            }
          ]
        }
      ]
    }
  end
end
