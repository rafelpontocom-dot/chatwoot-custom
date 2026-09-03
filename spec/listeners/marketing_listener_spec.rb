require 'rails_helper'

RSpec.describe MarketingListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:landing_url) { 'https://clinica.com.br/lp?utm_source=google&utm_medium=cpc&utm_campaign=fue&gclid=G1' }

  before { account.create_marketing_module_setting!(enabled: true) }

  describe '#conversation_created' do
    let(:conversation) do
      create(:conversation, account: account, inbox: inbox, contact: contact,
                            additional_attributes: { 'referer' => landing_url })
    end

    it 'reads the campaign out of the page the widget already reported' do
      event = Events::Base.new(:'conversation.created', Time.zone.now, conversation: conversation)

      expect { listener.conversation_created(event) }.to change(MarketingTouchpoint, :count).by(1)

      touchpoint = MarketingTouchpoint.last
      expect(touchpoint.source).to eq('widget_referer')
      expect(touchpoint.payload).to include('gclid' => 'G1', 'sub_origem' => '[MP] Google')
      expect(touchpoint.conversation_id).to eq(conversation.id)
    end

    it 'records the same conversation only once' do
      event = Events::Base.new(:'conversation.created', Time.zone.now, conversation: conversation)
      listener.conversation_created(event)

      expect { listener.conversation_created(event) }.not_to change(MarketingTouchpoint, :count)
    end

    it 'accepts attribution injected by an external bridge' do
      conversation.update!(
        additional_attributes: {},
        custom_attributes: {
          Marketing::RecordTouchpointService::ATTRIBUTION_KEY => { 'utm_source' => 'meta', 'fbclid' => 'F1' }
        }
      )
      event = Events::Base.new(:'conversation.created', Time.zone.now, conversation: conversation)

      expect { listener.conversation_created(event) }.to change(MarketingTouchpoint, :count).by(1)
      expect(MarketingTouchpoint.last.source).to eq('api_attribute')
    end

    it 'stays quiet for a conversation that carries no attribution' do
      conversation.update!(additional_attributes: {})
      event = Events::Base.new(:'conversation.created', Time.zone.now, conversation: conversation)

      expect { listener.conversation_created(event) }.not_to change(MarketingTouchpoint, :count)
    end

    it 'stays quiet when the account has not enabled the module' do
      account.marketing_module_setting.update!(enabled: false)
      event = Events::Base.new(:'conversation.created', Time.zone.now, conversation: conversation)

      expect { listener.conversation_created(event) }.not_to change(MarketingTouchpoint, :count)
    end
  end

  describe '#kanban_card_created' do
    let(:kanban_board) do
      create(:kanban_board, account: account, custom_field_definitions: [
               { 'key' => 'gclid', 'label' => 'gclid', 'field_type' => 'text', 'options' => [],
                 'layout' => { 'section' => 'marketing', 'position' => 1, 'width' => 'half' } }
             ])
    end
    let(:kanban_stage) { create(:kanban_stage, account: account, kanban_board: kanban_board) }

    it 'stamps the opportunity with what we know about the person' do
      create(:marketing_touchpoint, account: account, contact: contact, payload: { 'gclid' => 'G1' })
      contact.update!(
        additional_attributes: {
          Marketing::RecordTouchpointService::ATTRIBUTION_KEY => { 'last_touch' => { 'gclid' => 'G1' } }
        }
      )
      card = create(:kanban_card, account: account, kanban_board: kanban_board, kanban_stage: kanban_stage,
                                  contact: contact, inbox: inbox)
      event = Events::Base.new(:'kanban.card.created', Time.zone.now, card_id: card.id)

      listener.kanban_card_created(event)

      expect(card.reload.custom_field_values['gclid']).to eq('G1')
    end

    it 'does nothing without a card id' do
      event = Events::Base.new(:'kanban.card.created', Time.zone.now, {})

      expect { listener.kanban_card_created(event) }.not_to raise_error
    end
  end
end
