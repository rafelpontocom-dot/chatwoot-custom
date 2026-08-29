require 'rails_helper'

RSpec.describe Forms::SubmitPublicFormService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
  end
  let(:version) { template.publish!(schema: schema) }
  let(:invitation) do
    Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact
    ).perform.invitation
  end
  let(:conditional_fields) do
    [
      {
        'key' => 'deseja_consulta',
        'type' => 'select',
        'label' => 'Deseja agendar uma consulta?',
        'required' => true,
        'options' => %w[sim nao]
      },
      {
        'key' => 'melhor_horario',
        'type' => 'text',
        'label' => 'Melhor horário',
        'required' => true,
        'visible_when' => { 'field' => 'deseja_consulta', 'operator' => 'equals', 'value' => 'sim' }
      }
    ]
  end

  it 'persists validated answers and consumes the individual invitation' do
    submission = described_class.new(
      invitation: invitation,
      answers: {
        'nome_completo' => 'Pedro Raevo',
        'aceite_privacidade' => true
      }
    ).perform!

    expect(submission).to have_attributes(
      account: account,
      form_template_version: version,
      form_invitation: invitation,
      contact: contact,
      status: 'submitted'
    )
    expect(submission.answers).to include('nome_completo' => 'Pedro Raevo')
    expect(invitation.reload).to be_consumed
  end

  it 'does not consume the invitation when a required answer is missing' do
    expect do
      described_class.new(
        invitation: invitation,
        answers: { 'aceite_privacidade' => true }
      ).perform!
    end.to raise_error(ActiveRecord::RecordInvalid, /Nome completo/)

    expect(invitation.reload).to be_active
    expect(FormSubmission).not_to exist
  end

  it 'does not retain answer keys that are not present in the published schema' do
    submission = described_class.new(
      invitation: invitation,
      answers: {
        'nome_completo' => 'Pedro Raevo',
        'aceite_privacidade' => true,
        'admin_only' => 'não deve persistir'
      }
    ).perform!

    expect(submission.answers).not_to have_key('admin_only')
  end

  it 'does not consume the invitation when an email answer is invalid' do
    expect do
      described_class.new(
        invitation: invitation,
        answers: {
          'nome_completo' => 'Pedro Raevo',
          'email' => 'pedro-sem-dominio',
          'aceite_privacidade' => true
        }
      ).perform!
    end.to raise_error(ActiveRecord::RecordInvalid, /E-mail possui um formato inválido/)

    expect(invitation.reload).to be_active
    expect(FormSubmission).not_to exist
  end

  it 'does not require a conditional answer when its condition is not met' do
    conditional_template = FormTemplate.create!(
      account: account,
      name: 'Consulta',
      slug: 'consulta',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
    conditional_version = conditional_template.publish!(schema: conditional_schema)
    conditional_invitation = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: conditional_version,
      contact: contact
    ).perform.invitation

    submission = described_class.new(
      invitation: conditional_invitation,
      answers: { 'deseja_consulta' => 'nao' }
    ).perform!

    expect(submission.answers).to include('deseja_consulta' => 'nao')
    expect(conditional_invitation.reload).to be_consumed
  end

  it 'does not persist an answer for a conditional field that is not shown' do
    conditional_template = FormTemplate.create!(
      account: account,
      name: 'Consulta sem horário',
      slug: 'consulta-sem-horario',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
    conditional_version = conditional_template.publish!(schema: conditional_schema)
    conditional_invitation = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: conditional_version,
      contact: contact
    ).perform.invitation

    submission = described_class.new(
      invitation: conditional_invitation,
      answers: { 'deseja_consulta' => 'nao', 'melhor_horario' => 'Segunda às 9h' }
    ).perform!

    expect(submission.answers).to eq('deseja_consulta' => 'nao')
  end

  it 'maps only declared answers to the invited contact' do
    described_class.new(
      invitation: invitation,
      answers: {
        'nome_completo' => 'Pedro Raevo',
        'email' => 'pedro@raevo.io',
        'aceite_privacidade' => true
      }
    ).perform!

    expect(contact.reload.email).to eq('pedro@raevo.io')
  end

  it 'announces a completed commercial form for the linked opportunity' do
    card = create(:kanban_card, account: account, contact: contact)
    linked_invitation = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform.invitation

    expect(Rails.configuration.dispatcher).to receive(:dispatch).with(
      Events::Types::FORMS_SUBMISSION_COMPLETED,
      kind_of(ActiveSupport::TimeWithZone),
      hash_including(
        account_id: account.id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        form_template_id: template.id
      )
    )

    described_class.new(
      invitation: linked_invitation,
      answers: {
        'nome_completo' => 'Pedro Raevo',
        'aceite_privacidade' => true
      }
    ).perform!
  end

  it 'stores a permitted document with a clinical anamnese submission' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese com exame',
        slug: 'anamnese-com-exame',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      clinical_version = clinical_template.publish!(schema: clinical_schema)
      clinical_invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: clinical_version,
        contact: contact
      ).perform.invitation

      submission = described_class.new(
        invitation: clinical_invitation,
        answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true },
        attachments: { 'exames' => [uploaded_pdf] }
      ).perform!

      expect(submission.clinical_attachments).to be_attached
      expect(submission.clinical_attachments.first.filename.to_s).to eq('exame.pdf')
      expect(submission.answers).to eq({})
      expect(clinical_invitation.reload).to be_consumed
    end
  end

  it 'does not consume an anamnese invitation when the attachment type is not allowed' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese com documento',
        slug: 'anamnese-com-documento',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      clinical_version = clinical_template.publish!(schema: clinical_schema)
      clinical_invitation = Forms::CreateInvitationService.new(
        account: account,
        form_template_version: clinical_version,
        contact: contact
      ).perform.invitation

      expect do
        described_class.new(
          invitation: clinical_invitation,
          answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true },
          attachments: { 'exames' => [uploaded_text_file] }
        ).perform!
      end.to raise_error(ActiveRecord::RecordInvalid, /arquivo permitido/)

      expect(clinical_invitation.reload).to be_active
      expect(FormSubmission).not_to exist
    end
  end

  private

  def schema
    {
      'crm_mapping' => { 'contact' => { 'email' => 'email' } },
      'sections' => [
        {
          'key' => 'identificacao',
          'title' => 'Identificação',
          'fields' => [
            { 'key' => 'nome_completo', 'type' => 'text', 'label' => 'Nome completo', 'required' => true },
            { 'key' => 'email', 'type' => 'email', 'label' => 'E-mail' },
            { 'key' => 'aceite_privacidade', 'type' => 'consent', 'label' => 'Li e aceito', 'required' => true }
          ]
        }
      ]
    }
  end

  def conditional_schema
    {
      'sections' => [
        {
          'key' => 'consulta',
          'fields' => conditional_fields
        }
      ]
    }
  end

  def clinical_schema
    {
      'sections' => [
        {
          'key' => 'saude',
          'fields' => [
            { 'key' => 'alergias', 'type' => 'textarea', 'label' => 'Alergias', 'required' => true },
            { 'key' => 'exames', 'type' => 'attachment', 'label' => 'Exames recentes', 'required' => true },
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

  def uploaded_pdf
    uploaded_file('exame.pdf', 'application/pdf', '%PDF-1.4 exame')
  end

  def uploaded_text_file
    uploaded_file('anotacao.txt', 'text/plain', 'anotação')
  end

  def uploaded_file(filename, content_type, content)
    tempfile = Tempfile.new(File.basename(filename, '.*'))
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind
    ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: filename, type: content_type)
  end
end
