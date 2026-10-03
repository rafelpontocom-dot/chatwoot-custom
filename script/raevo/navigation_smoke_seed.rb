# Run only against the isolated test database used by the browser smoke test.
abort 'Navigation smoke data requires RAILS_ENV=test' unless Rails.env.test?

InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_NAME').update!(value: 'RAEVO CRM')

account = Account.create!(name: 'Raevo navigation smoke', locale: 'pt_BR')
account.enable_features!(*Featurable::FEATURE_LIST.select { |feature| feature['enabled'] }.pluck('name'))
account.enable_features!('conversation_unread_counts')
user = User.new(
  name: 'Navigation smoke',
  email: ENV.fetch('TEST_USER_EMAIL', 'navigation-smoke@raevo.test'),
  password: ENV.fetch('TEST_USER_PASSWORD', 'NavigationSmoke1!')
)
user.skip_confirmation!
user.save!
AccountUser.create!(account: account, user: user, role: :administrator)

channel = Channel::Api.create!(account: account)
inbox = Inbox.create!(account: account, channel: channel, name: 'Smoke API')
InboxMember.create!(inbox: inbox, user: user)
inbox.avatar.attach(
  io: File.open(Rails.root.join('spec/assets/avatar.png')),
  filename: 'avatar.png',
  content_type: 'image/png'
)

board = KanbanBoard.create!(account: account, name: 'Smoke pipeline', calendar_enabled: true)
stage = KanbanStage.create!(account: account, kanban_board: board, name: 'Qualificacao', color: 'blue')
contact = Contact.create!(
  account: account,
  name: 'Pedro Raevo Smoke',
  email: 'pedro-smoke@raevo.test',
  additional_attributes: { social_profiles: { whatsapp: 'pedrosmoke' } }
)
contact_inbox = ContactInbox.create!(contact: contact, inbox: inbox, source_id: 'navigation-smoke')
conversation = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
Message.create!(account: account, inbox: inbox, conversation: conversation, sender: contact,
                message_type: :incoming, content: 'Mensagem de validacao da navegacao')
assigned_contact = Contact.create!(account: account, name: 'Pedro Raevo Assigned Smoke')
assigned_contact_inbox = ContactInbox.create!(contact: assigned_contact, inbox: inbox, source_id: 'navigation-assigned-smoke')
Conversation.create!(account: account, inbox: inbox, contact: assigned_contact, contact_inbox: assigned_contact_inbox, assignee: user)
Label.create!(account: account, title: 'alpha-smoke', color: '#00B8C6', position: 0, show_on_sidebar: true)
Label.create!(account: account, title: 'zulu-smoke', color: '#C7A97A', position: 1, show_on_sidebar: true)
Conversations::UnreadCounts::Builder.new(account).build_base!
KanbanCard.create!(
  account: account,
  kanban_board: board,
  kanban_stage: stage,
  contact: contact,
  inbox: inbox,
  conversation: conversation,
  origin: 'manual',
  position: 0,
  subject: 'Oportunidade smoke'
)
FinanceModuleSetting.create!(account: account, enabled: true, market: 'BR')

puts({ account_id: account.id, board_id: board.id, contact_id: contact.id }.to_json)
