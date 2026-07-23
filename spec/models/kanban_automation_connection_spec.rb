require 'rails_helper'

RSpec.describe KanbanAutomationConnection do
  it 'creates a secret and requires a secure webhook URL' do
    account = create(:account)
    board = create(:kanban_board, account: account)
    connection = build(
      :kanban_automation_connection,
      account: account,
      kanban_board: board,
      webhook_url: 'https://automacao.example.test/hooks/lead'
    )

    expect(connection).to be_valid
    expect { connection.save! }.to change(connection, :secret).from(nil)

    connection.webhook_url = 'http://automacao.example.test/hooks/lead'

    expect(connection).not_to be_valid
    expect(connection.errors[:webhook_url]).to be_present
  end
end
