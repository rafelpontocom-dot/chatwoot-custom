require 'rails_helper'

describe Labels::UpdateService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:label) { create(:label, account: account) }
  let(:contact) { conversation.contact }

  before do
    conversation.label_list.add(label.title)
    conversation.save!

    contact.label_list.add(label.title)
    contact.save!
  end

  describe '#perform' do
    it 'updates associated conversations/contacts labels' do
      expect(conversation.label_list).to eq([label.title])
      expect(contact.label_list).to eq([label.title])

      described_class.new(
        new_label_title: 'updated-label-title',
        old_label_title: label.title,
        account_id: account.id
      ).perform

      expect(conversation.reload.label_list).to eq(['updated-label-title'])
      expect(contact.reload.label_list).to eq(['updated-label-title'])
    end

    # Contrato de upgrade `labels-on-opportunities`: a oportunidade do Raevo também
    # leva etiquetas, e renomear tem de chegar a ela.
    it 'renames the label on the account opportunities too' do
      card = create(:kanban_card, account: account)
      card.label_list.add(label.title)
      card.save!

      described_class.new(new_label_title: 'updated-label-title', old_label_title: label.title, account_id: account.id).perform

      expect(card.reload.label_list).to eq(['updated-label-title'])
    end
  end
end
