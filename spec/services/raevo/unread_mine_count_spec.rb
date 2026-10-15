require 'rails_helper'

# 123jpnbcxh5: o ponto da guia acende pelas conversas por ler de quem está ligado.
RSpec.describe Raevo::UnreadMineCount do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:hidden_inbox) { create(:inbox, account: account) }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  def conversation_with_incoming(assignee: nil, in_inbox: inbox, seen_after: false)
    conversation = create(:conversation, account: account, inbox: in_inbox, assignee: assignee)
    create(:message, account: account, inbox: in_inbox, conversation: conversation, message_type: :incoming)
    conversation.update!(agent_last_seen_at: 1.minute.from_now) if seen_after
    conversation
  end

  it 'counts the unread conversations assigned to the agent in the inboxes they see' do
    conversation_with_incoming(assignee: agent)
    conversation_with_incoming(assignee: agent, seen_after: true)
    conversation_with_incoming
    conversation_with_incoming(assignee: agent, in_inbox: hidden_inbox)

    expect(described_class.new(account: account, user: agent).count).to eq(1)
  end
end
