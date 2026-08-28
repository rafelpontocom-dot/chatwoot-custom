require 'rails_helper'

RSpec.describe Forms::SubmissionEventDispatcher do
  let(:account) { create(:account) }
  let(:card) { create(:kanban_card, account: account) }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Captação',
      slug: 'captacao',
      category: 'lead_capture',
      access_classification: 'commercial'
    )
  end
  let(:version) do
    template.publish!(
      schema: {
        'sections' => [
          {
            'key' => 'dados',
            'fields' => [{ 'key' => 'nome', 'label' => 'Nome', 'type' => 'text' }]
          }
        ]
      }
    )
  end
  let(:submission) do
    FormSubmission.create!(
      account: account,
      form_template_version: version,
      kanban_card: card,
      answers: { 'nome' => 'Pedro Raevo' },
      metadata: {},
      submitted_at: Time.current
    )
  end

  before { submission }

  it 'dispatches a sanitized event scoped to the linked opportunity' do
    expect(Rails.configuration.dispatcher).to receive(:dispatch) do |event_name, timestamp, data|
      expect(event_name).to eq(Events::Types::FORMS_SUBMISSION_COMPLETED)
      expect(timestamp).to be_a(ActiveSupport::TimeWithZone)
      expect(data).to include(
        account_id: account.id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        form_submission_id: submission.id,
        form_template_id: template.id,
        event_key: "forms-submission:#{submission.id}:completed"
      )
      expect(data).not_to have_key(:answers)
    end

    described_class.new(submission: submission).dispatch
  end

  it 'does not dispatch when the submission has no linked opportunity' do
    submission.update!(kanban_card: nil)

    expect(Rails.configuration.dispatcher).not_to receive(:dispatch)

    described_class.new(submission: submission).dispatch
  end

  it 'does not dispatch a sensitive-health submission to automations' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      clinical_template = FormTemplate.create!(
        account: account,
        name: 'Anamnese',
        slug: 'anamnese',
        category: 'clinical',
        access_classification: 'sensitive_health'
      )
      clinical_version = clinical_template.publish!(schema: clinical_schema)
      clinical_submission = FormSubmission.create_from_answers!(
        account: account,
        form_template_version: clinical_version,
        kanban_card: card,
        answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true },
        metadata: {}
      )

      expect(Rails.configuration.dispatcher).not_to receive(:dispatch)

      described_class.new(submission: clinical_submission).dispatch
    end
  end

  private

  def clinical_schema
    {
      'sections' => [
        {
          'key' => 'saude',
          'fields' => [
            { 'key' => 'alergias', 'label' => 'Alergias', 'type' => 'textarea', 'required' => true },
            {
              'key' => 'consentimento_clinico',
              'label' => 'Autorizo o tratamento dos dados de saúde para atendimento',
              'type' => 'consent',
              'required' => true
            }
          ]
        }
      ]
    }
  end
end
