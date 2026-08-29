require 'rails_helper'

RSpec.describe Forms::ClinicalRetentionService do
  let(:account) { create(:account) }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Anamnese',
      slug: 'anamnese-retencao',
      category: 'clinical',
      access_classification: 'sensitive_health',
      settings: { 'clinical_retention_days' => 30 }
    )
  end
  let(:version) { template.publish!(schema: schema) }

  around do |example|
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      example.run
    end
  end

  it 'discards only expired clinical answers and attachments, preserving an audit record' do
    expired_submission = create_submission(submitted_at: 31.days.ago)
    current_submission = create_submission(submitted_at: 29.days.ago)
    expired_submission.clinical_attachments.attach(
      io: StringIO.new('%PDF-1.4 exame'),
      filename: 'exame.pdf',
      content_type: 'application/pdf'
    )

    described_class.new(now: Time.current).perform!

    expect(expired_submission.reload).to have_attributes(
      status: 'discarded',
      answers: {},
      sensitive_answers_ciphertext: nil,
      metadata: {}
    )
    expect(expired_submission.clinical_attachments).not_to be_attached
    expect(expired_submission.form_access_audits.last).to have_attributes(action: 'retention_discarded', actor: nil)
    expect(current_submission.reload).to have_attributes(status: 'submitted')
    expect(current_submission.sensitive_answers).to include('alergias' => 'Penicilina')
  end

  it 'does not discard a clinical submission without an explicit retention period' do
    template.update!(settings: {})
    submission = create_submission(submitted_at: 10.years.ago)

    described_class.new(now: Time.current).perform!

    expect(submission.reload).to have_attributes(status: 'submitted')
    expect(submission.sensitive_answers).to include('alergias' => 'Penicilina')
  end

  private

  def create_submission(submitted_at:)
    FormSubmission.create_from_answers!(
      account: account,
      form_template_version: version,
      answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true },
      metadata: { 'source' => 'clinical_invitation' },
      submitted_at: submitted_at
    )
  end

  def schema
    {
      'sections' => [
        {
          'key' => 'saude',
          'title' => 'Saúde',
          'fields' => [
            { 'key' => 'alergias', 'type' => 'textarea', 'label' => 'Alergias', 'required' => true },
            { 'key' => 'consentimento_clinico', 'type' => 'consent', 'label' => 'Autorizo', 'required' => true }
          ]
        }
      ]
    }
  end
end
