require 'rails_helper'

RSpec.describe KanbanBoard do
  describe 'custom field presentation' do
    it 'preserves the important flag in a custom field definition' do
      board = create(
        :kanban_board,
        custom_field_definitions: [
          { key: 'budget', label: 'Budget', field_type: 'currency', important: true }
        ]
      )

      expect(board.custom_field_definitions.first).to include('important' => true)
    end

    it 'normalizes custom opportunity tabs and removes duplicates' do
      board = build(
        :kanban_board,
        custom_field_sections: [
          { key: ' consultation ', label: ' Consulta ' },
          { key: 'consultation', label: 'Duplicada' },
          { key: 'marketing', label: 'Reservada' },
          { key: '', label: 'Inválida' }
        ]
      )

      board.valid?

      expect(board.custom_field_sections).to eq(
        [
          { 'key' => 'consultation', 'label' => 'Consulta', 'color' => 'slate', 'groups' => [] },
          { 'key' => 'marketing', 'label' => 'Marketing', 'color' => 'slate', 'groups' => [] }
        ]
      )
    end
  end

  describe 'defaults' do
    it 'disables automatic card creation for new boards' do
      board = described_class.new

      expect(board.auto_create_cards_from_conversations).to be(false)
    end

    it 'keeps new boards visible to all agents' do
      board = described_class.new

      expect(board.visibility_mode).to eq('all_agents')
    end

    it 'keeps persisted boards visible to all agents when visibility is not specified' do
      board = create(:kanban_board)

      expect(board.visibility_mode).to eq('all_agents')
    end

    it 'uses default sales options when none are configured' do
      board = described_class.new

      expect(board.configured_next_action_types).to include('Enviar proposta')
      expect(board.configured_lost_reason_options).to include('Sem resposta')
    end
  end

  describe 'validations' do
    it 'prevents duplicate active names inside an account' do
      account = create(:account)
      create(:kanban_board, account: account, name: 'Sales')

      board = build(:kanban_board, account: account, name: 'Sales')

      expect(board).not_to be_valid
      expect(board.errors[:name]).to be_present
    end

    it 'allows the same name when the previous board is inactive' do
      account = create(:account)
      create(:kanban_board, account: account, name: 'Sales', active: false)

      board = build(:kanban_board, account: account, name: 'Sales')

      expect(board).to be_valid
    end

    it 'allows the same name in another account' do
      create(:kanban_board, account: create(:account), name: 'Sales')
      other_account = create(:account)

      board = build(:kanban_board, account: other_account, name: 'Sales')

      expect(board).to be_valid
    end

    it 'accepts supported visibility modes' do
      account = create(:account)

      described_class::VISIBILITY_MODES.each do |visibility_mode|
        board = build(:kanban_board, account: account, visibility_mode: visibility_mode)

        expect(board).to be_valid
      end
    end

    it 'rejects unsupported visibility modes' do
      board = build(:kanban_board, account: create(:account), visibility_mode: 'private')

      expect(board).not_to be_valid
      expect(board.errors[:visibility_mode]).to be_present
    end

    it 'defaults to all_inboxes inbox scope' do
      board = described_class.new

      expect(board.inbox_scope_mode).to eq('all_inboxes')
    end

    it 'persists all_inboxes as default inbox scope' do
      board = create(:kanban_board)

      expect(board.inbox_scope_mode).to eq('all_inboxes')
    end

    it 'accepts supported inbox scope modes' do
      account = create(:account)

      described_class::INBOX_SCOPE_MODES.each do |mode|
        board = build(:kanban_board, account: account, inbox_scope_mode: mode)

        expect(board).to be_valid
      end
    end

    it 'rejects unsupported inbox scope modes' do
      board = build(:kanban_board, account: create(:account), inbox_scope_mode: 'restricted')

      expect(board).not_to be_valid
      expect(board.errors[:inbox_scope_mode]).to be_present
    end

    it 'normalizes sales option lists' do
      board = build(
        :kanban_board,
        next_action_types: [' Enviar proposta ', '', 'Enviar proposta', 'Cobrar retorno'],
        lost_reason_options: [' Preço ', nil, 'Preço', 'Sem resposta']
      )

      board.valid?

      expect(board.next_action_types).to eq(['Enviar proposta', 'Cobrar retorno'])
      expect(board.lost_reason_options).to eq(['Preço', 'Sem resposta'])
    end

    it 'normalizes configurable compact fields and stale stage thresholds' do
      stage = create(:kanban_stage)
      board = stage.kanban_board
      board.compact_card_field_keys = [' valor_estimado ', '', 'valor_estimado', 'origem']
      board.stale_stage_thresholds = { stage.id.to_s => '3', 'invalid' => '10' }

      board.valid?

      expect(board.compact_card_field_keys).to eq(%w[valor_estimado origem])
      expect(board.stale_stage_thresholds).to eq(stage.id.to_s => 3)
    end

    it 'falls back to a default so the stalled signal works before anyone configures it' do
      stage = create(:kanban_stage)

      expect(stage.kanban_board.stale_days_for_stage(stage.id))
        .to eq(described_class::DEFAULT_STALE_DAYS)
    end

    it 'lets the per-stage threshold win over the default' do
      stage = create(:kanban_stage)
      board = stage.kanban_board
      board.update!(stale_stage_thresholds: { stage.id.to_s => 21 })

      expect(board.stale_days_for_stage(stage.id)).to eq(21)
    end

    it 'supports the custom field types required by commercial boards' do
      board = create(:kanban_board)
      board.custom_field_definitions = %w[textarea currency multiselect url].map do |field_type|
        {
          key: field_type,
          label: field_type.titleize,
          field_type: field_type,
          options: field_type == 'multiselect' ? %w[A B] : []
        }
      end

      board.valid?

      expect(board.custom_field_definitions.pluck('field_type')).to eq(%w[textarea currency multiselect url])
    end
  end

  describe 'associations' do
    it 'exposes board members as visible users' do
      board = create(:kanban_board)
      user = create(:user, account: board.account)
      create(:kanban_board_member, account: board.account, kanban_board: board, user: user)

      expect(board.kanban_board_members.count).to eq(1)
      expect(board.visible_users).to contain_exactly(user)
    end

    it 'exposes allowed inboxes through kanban_board_inboxes' do
      board = create(:kanban_board)
      inbox = create(:inbox, account: board.account)
      create(:kanban_board_inbox, account: board.account, kanban_board: board, inbox: inbox)

      expect(board.kanban_board_inboxes.count).to eq(1)
      expect(board.allowed_inboxes).to contain_exactly(inbox)
    end
  end

  describe '#inbox_allowed?' do
    let(:account) { create(:account) }
    let(:board) { create(:kanban_board, account: account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:other_account_inbox) { create(:inbox) }

    it 'accepts any account inbox when in all_inboxes mode' do
      expect(board).to be_all_inboxes

      expect(board.inbox_allowed?(inbox)).to be(true)
    end

    it 'accepts inbox by id in all_inboxes mode' do
      expect(board.inbox_allowed?(inbox.id)).to be(true)
    end

    it 'rejects inbox from another account in all_inboxes mode' do
      expect(board.inbox_allowed?(other_account_inbox)).to be(false)
    end

    it 'accepts a selected inbox in selected_inboxes mode' do
      board.update!(inbox_scope_mode: 'selected_inboxes')
      create(:kanban_board_inbox, account: account, kanban_board: board, inbox: inbox)

      expect(board.inbox_allowed?(inbox)).to be(true)
    end

    it 'rejects an unselected inbox in selected_inboxes mode' do
      board.update!(inbox_scope_mode: 'selected_inboxes')

      expect(board.inbox_allowed?(inbox)).to be(false)
    end

    it 'rejects all inboxes when selected_inboxes mode has no associations' do
      board.update!(inbox_scope_mode: 'selected_inboxes')

      expect(board.inbox_allowed?(inbox)).to be(false)
      expect(board.inbox_allowed?(other_account_inbox)).to be(false)
    end

    it 'rejects inbox from another account in selected_inboxes mode' do
      board.update!(inbox_scope_mode: 'selected_inboxes')
      create(:kanban_board_inbox, account: account, kanban_board: board, inbox: inbox)

      expect(board.inbox_allowed?(other_account_inbox)).to be(false)
    end

    it 'returns false for nil or blank' do
      expect(board.inbox_allowed?(nil)).to be(false)
      expect(board.inbox_allowed?('')).to be(false)
    end
  end

  describe 'scope .accepting_inbox' do
    it 'includes all_inboxes boards' do
      board = create(:kanban_board)
      inbox = create(:inbox, account: board.account)

      expect(described_class.accepting_inbox(inbox.id).ids).to include(board.id)
    end

    it 'includes selected_inboxes boards when inbox is associated' do
      board = create(:kanban_board, inbox_scope_mode: 'selected_inboxes')
      inbox = create(:inbox, account: board.account)
      create(:kanban_board_inbox, account: board.account, kanban_board: board, inbox: inbox)

      expect(described_class.accepting_inbox(inbox.id).ids).to include(board.id)
    end

    it 'excludes selected_inboxes boards when inbox is not associated' do
      board = create(:kanban_board, inbox_scope_mode: 'selected_inboxes')
      inbox = create(:inbox, account: board.account)

      expect(described_class.accepting_inbox(inbox.id).ids).not_to include(board.id)
    end

    it 'excludes selected_inboxes boards when inbox belongs to another account' do
      board = create(:kanban_board, inbox_scope_mode: 'selected_inboxes')
      other_account = create(:account)
      inbox = create(:inbox, account: other_account)

      expect(described_class.accepting_inbox(inbox.id).ids).not_to include(board.id)
    end
  end
end
