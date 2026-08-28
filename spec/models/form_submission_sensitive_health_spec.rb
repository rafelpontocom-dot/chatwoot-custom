require 'rails_helper'

RSpec.describe FormSubmission do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Anamnese inicial',
      slug: 'anamnese-inicial',
      category: 'clinical',
      access_classification: 'sensitive_health'
    )
  end
  let(:version) { template.publish!(schema: schema) }

  around do |example|
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      example.run
    end
  end

  it 'stores clinical answers outside the regular answers document' do
    submission = described_class.create_from_answers!(
      account: account,
      form_template_version: version,
      contact: contact,
      answers: { 'alergias' => 'Penicilina', 'consentimento_clinico' => true }
    )

    expect(submission.answers).to eq({})
    expect(submission.sensitive_answers_ciphertext).not_to include('Penicilina')
    expect(submission.sensitive_answers).to include('alergias' => 'Penicilina')
    expect(submission.summary_payload).not_to have_key(:answers)
  end

  private

  def schema
    {
      'sections' => [
        {
          'key' => 'saude',
          'title' => 'Informações de saúde',
          'fields' => [
            { 'key' => 'alergias', 'type' => 'textarea', 'label' => 'Alergias', 'required' => true },
            {
              'key' => 'consentimento_clinico',
              'type' => 'consent',
              'label' => 'Autorizo o tratamento destas informações para meu atendimento',
              'required' => true
            }
          ]
        }
      ]
    }
  end
end
