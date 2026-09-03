require 'rails_helper'

RSpec.describe Marketing::StampCardAttributionService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:kanban_board) { create(:kanban_board, account: account, custom_field_definitions: marketing_definitions) }
  let(:kanban_stage) { create(:kanban_stage, account: account, kanban_board: kanban_board) }
  let(:inbox) { create(:inbox, account: account) }
  let(:kanban_card) do
    create(:kanban_card, account: account, kanban_board: kanban_board, kanban_stage: kanban_stage,
                         contact: contact, inbox: inbox)
  end

  let(:marketing_definitions) do
    %w[origem_do_lead sub_origem utm_source utm_campaign gclid].each_with_index.map do |key, index|
      {
        'key' => key, 'label' => key, 'field_type' => 'text', 'options' => [],
        'layout' => { 'section' => 'marketing', 'position' => index + 1, 'width' => 'half' }
      }
    end
  end

  before do
    account.create_marketing_module_setting!(enabled: true)
    contact.update!(
      additional_attributes: {
        Marketing::RecordTouchpointService::ATTRIBUTION_KEY => {
          'last_touch' => { 'utm_source' => 'google', 'utm_campaign' => 'fue', 'gclid' => 'G1',
                            'origem_do_lead' => 'Mídia Paga', 'landing_page_full' => 'https://c.com.br/lp?x=1' }
        }
      }
    )
  end

  it 'fills the marketing fields from what we know about the person' do
    described_class.new(kanban_card: kanban_card).perform

    expect(kanban_card.reload.custom_field_values).to include(
      'utm_source' => 'google', 'utm_campaign' => 'fue', 'gclid' => 'G1', 'origem_do_lead' => 'Mídia Paga'
    )
  end

  it 'never writes over something a person already typed' do
    kanban_card.update!(custom_field_values: { 'utm_source' => 'digitado a mao' })

    described_class.new(kanban_card: kanban_card).perform

    values = kanban_card.reload.custom_field_values
    expect(values['utm_source']).to eq('digitado a mao')
    expect(values['gclid']).to eq('G1')
  end

  it 'leaves a board that never configured the marketing preset alone' do
    kanban_board.update!(custom_field_definitions: [])

    expect { described_class.new(kanban_card: kanban_card).perform }
      .not_to(change { kanban_card.reload.custom_field_values })
  end

  it 'prefers the touchpoint of the conversation that opened the opportunity' do
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    kanban_card.update!(conversation: conversation)
    create(
      :marketing_touchpoint,
      account: account, contact: contact, conversation: conversation,
      payload: { 'utm_source' => 'tiktok', 'utm_campaign' => 'verao' }
    )

    described_class.new(kanban_card: kanban_card).perform

    expect(kanban_card.reload.custom_field_values['utm_source']).to eq('tiktok')
  end

  it 'does nothing when the person carries no attribution' do
    contact.update!(additional_attributes: {})

    expect { described_class.new(kanban_card: kanban_card).perform }
      .not_to(change { kanban_card.reload.custom_field_values })
  end
end
