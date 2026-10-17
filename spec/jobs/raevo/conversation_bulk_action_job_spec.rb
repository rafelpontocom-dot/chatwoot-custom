require 'rails_helper'

RSpec.describe Raevo::ConversationBulkActionJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let!(:conversations) { create_list(:conversation, 2, account: account, inbox: inbox, status: :open) }
  let(:ids) { conversations.map(&:display_id) }

  def perform(operation, value = nil)
    described_class.perform_now(account, admin, ids, operation, value)
  end

  it 'resolves through the native bulk job' do
    perform('resolve')

    expect(conversations.map { |conversation| conversation.reload.status }).to all(eq('resolved'))
  end

  it 'sets the priority' do
    perform('priority', 'urgent')

    expect(conversations.map { |conversation| conversation.reload.priority }).to all(eq('urgent'))
  end

  it 'marks as read and as unread' do
    conversation = conversations.first
    message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)

    perform('read')
    expect(conversation.reload.agent_last_seen_at).to be > message.created_at

    perform('unread')
    expect(conversation.reload.agent_last_seen_at).to be < message.created_at
  end

  it 'adds labels' do
    perform('add_labels', ['retorno'])

    expect(conversations.map { |conversation| conversation.reload.label_list }).to all(include('retorno'))
  end

  it 'deletes through the native delete service' do
    expect { perform('delete') }.to have_enqueued_job(DeleteObjectJob).exactly(2).times
  end
end
