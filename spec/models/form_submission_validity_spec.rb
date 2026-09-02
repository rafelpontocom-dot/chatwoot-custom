require 'rails_helper'

RSpec.describe FormSubmission do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
  let(:schema) do
    {
      'sections' => [
        { 'key' => 'geral', 'fields' => [{ 'key' => 'peso', 'label' => 'Peso', 'type' => 'number' }] }
      ]
    }
  end
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Anamnese',
      slug: 'anamnese',
      category: 'pre_consultation',
      access_classification: 'restricted',
      settings: settings
    )
  end
  let(:version) { template.publish!(schema: schema) }
  let(:submission) do
    described_class.create_from_answers!(
      account: account,
      form_template_version: version,
      contact: contact,
      answers: { 'peso' => '94' }
    )
  end

  context 'when the form sets no validity' do
    let(:settings) { {} }

    it 'never goes out of date' do
      expect(submission.valid_until).to be_nil
      expect(submission).not_to be_answer_expired
      expect(submission.summary_payload[:answer_expired]).to be(false)
    end
  end

  context 'when the form is valid for six months' do
    let(:settings) { { 'answer_validity_days' => 180 } }

    it 'stays valid inside the window' do
      expect(submission.valid_until).to be_within(1.minute).of(submission.submitted_at + 180.days)
      expect(submission).not_to be_answer_expired
    end

    it 'is marked out of date afterwards, and kept' do
      travel_to(submission.submitted_at + 181.days) do
        expect(submission.reload).to be_answer_expired
        expect(described_class.find_by(id: submission.id)).to be_present
        expect(submission.summary_payload[:answer_expired]).to be(true)
      end
    end
  end

  describe '#restricted_summary_payload' do
    let(:settings) { {} }

    it 'says a form was answered without carrying the answers' do
      payload = submission.restricted_summary_payload

      expect(payload[:restricted]).to be(true)
      expect(payload[:id]).to eq(submission.id)
      expect(payload[:form_name]).to eq('Anamnese')
      expect(payload).not_to have_key(:answers)
    end
  end
end
