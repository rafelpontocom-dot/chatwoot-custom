require 'rails_helper'

RSpec.describe Forms::CreateInvitationService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
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
  let(:version) { template.publish!(schema: schema) }

  it 'returns the raw token only when it creates the invitation' do
    result = described_class.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card,
      expires_at: 48.hours.from_now
    ).perform

    expect(result.invitation).to be_persisted
    expect(result.token).to match(/\A[a-zA-Z0-9_-]{32,}\z/)
    expect(result.invitation.token_digest).to eq(FormInvitation.digest_token(result.token))
  end

  private

  def schema
    {
      'crm_destination' => {
        'kanban_board_id' => card.kanban_board_id,
        'kanban_stage_id' => card.kanban_stage_id,
        'inbox_id' => card.inbox_id,
        'opportunity_policy' => 'reuse_open'
      },
      'sections' => [
        {
          'key' => 'identificacao',
          'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome completo' }]
        }
      ]
    }
  end
end
