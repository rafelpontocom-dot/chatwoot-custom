require 'rails_helper'

RSpec.describe KanbanCard do
  describe 'commercial lifecycle' do
    it 'records immutable events for creation and relevant commercial changes' do
      card = create(:kanban_card, amount_cents: 100_00)

      expect(card.kanban_card_events.pluck(:event_type)).to eq(['card_created'])

      card.update!(amount_cents: 150_00, owner: create(:user, account: card.account))

      expect(card.kanban_card_events.order(:id).pluck(:event_type)).to eq(
        %w[card_created owner_changed amount_changed]
      )
      amount_event = card.kanban_card_events.find_by!(event_type: 'amount_changed')
      expect(amount_event.change_set).to eq('amount_cents' => [100_00, 150_00])
    end

    it 'archives and restores a card without losing its history' do
      card = create(:kanban_card)
      actor = create(:user, account: card.account)

      card.archive!(actor: actor)

      expect(card).to have_attributes(active: false, archived_by: actor)
      expect(card.archived_at).to be_present
      expect(card.kanban_card_events.order(:id).last.event_type).to eq('card_archived')

      card.restore!(actor: actor)

      expect(card).to have_attributes(active: true, archived_at: nil, archived_by: nil)
      expect(card.kanban_card_events.order(:id).pluck(:event_type)).to eq(
        %w[card_created card_archived card_restored]
      )
    end

    it 'records reopening without duplicating the previous terminal event' do
      card = create(:kanban_card)

      card.update!(won_at: Time.current)
      card.update!(won_at: nil)

      expect(card.kanban_card_events.order(:id).pluck(:event_type)).to eq(
        %w[card_created card_won card_reopened]
      )
    end

    it 'records a terminal status change without treating it as reopened' do
      card = create(:kanban_card)

      card.update!(won_at: Time.current)
      card.update!(won_at: nil, lost_at: Time.current, lost_reason: 'Preço')

      expect(card.kanban_card_events.order(:id).pluck(:event_type)).to eq(
        %w[card_created card_won card_lost]
      )
    end

    it 'stores an optional expected close date' do
      card = build(:kanban_card, expected_close_date: Date.new(2026, 8, 15))

      expect(card).to be_valid
      expect(card.expected_close_date).to eq(Date.new(2026, 8, 15))
    end
  end

  describe 'commercial custom fields' do
    it 'normalizes currency and multiselect values' do
      board = create(
        :kanban_board,
        custom_field_definitions: [
          { key: 'orcamento', label: 'Orçamento', field_type: 'currency' },
          { key: 'produtos', label: 'Produtos', field_type: 'multiselect', options: %w[Plano Curso Consultoria] }
        ]
      )
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        custom_field_values: { orcamento: '1250.50', produtos: ['Plano', '', 'Curso', 'Plano'] }
      )

      card.valid?

      expect(card.custom_field_values).to eq('orcamento' => 1250.5, 'produtos' => %w[Plano Curso])
    end

    it 'preserves false as a filled boolean value' do
      board = create(
        :kanban_board,
        custom_field_definitions: [
          { key: 'aceitou', label: 'Aceitou?', field_type: 'boolean', required_stage_ids: [] }
        ]
      )
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      board.update!(
        custom_field_definitions: [
          { key: 'aceitou', label: 'Aceitou?', field_type: 'boolean', required_stage_ids: [stage.id] }
        ]
      )
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        custom_field_values: { aceitou: false }
      )

      expect(card).to be_valid
      expect(card.custom_field_values).to eq('aceitou' => false)
    end

    it 'applies required field conditions using the opportunity value' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      board.update!(
        custom_field_definitions: [
          {
            key: 'desconto_aprovado',
            label: 'Desconto aprovado?',
            field_type: 'boolean',
            required_stage_ids: [stage.id],
            condition: { field_key: 'system_amount', equals: '1500' }
          }
        ]
      )
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        amount_cents: 150_000,
        custom_field_values: {}
      )

      expect(card).not_to be_valid
      expect(card.errors[:custom_field_values]).to include('desconto_aprovado is required')

      card.amount_cents = 100_000
      expect(card).to be_valid
    end

    it 'applies required field conditions using the conversation agent' do
      conversation = create(:conversation)
      agent = create(:user, account: conversation.account)
      conversation.update!(assignee: agent)
      board = create(:kanban_board, account: conversation.account)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      board.update!(
        custom_field_definitions: [
          {
            key: 'aprovacao_comercial',
            label: 'Aprovação comercial',
            field_type: 'text',
            required_stage_ids: [stage.id],
            condition: {
              field_key: 'system_assignee_id',
              equals: agent.id.to_s
            }
          }
        ]
      )
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        conversation: conversation,
        contact: conversation.contact,
        inbox: conversation.inbox,
        custom_field_values: {}
      )

      expect(card).not_to be_valid
      expect(card.errors[:custom_field_values]).to include('aprovacao_comercial is required')
    end

    it 'uses the opportunity value in custom field formulas' do
      board = create(
        :kanban_board,
        custom_field_definitions: [
          { key: 'taxa', label: 'Taxa', field_type: 'currency' },
          {
            key: 'valor_total',
            label: 'Valor total',
            field_type: 'formula',
            formula: 'system_amount + taxa'
          }
        ]
      )
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        amount_cents: 150_000,
        custom_field_values: { taxa: 100 }
      )

      expect(card).to be_valid
      expect(card.custom_field_values).to include('valor_total' => 1600.0)
    end

    it 'accepts a comma as the decimal separator in formulas' do
      board = create(
        :kanban_board,
        custom_field_definitions: [
          {
            key: 'comissao',
            label: 'Comissão',
            field_type: 'formula',
            formula: 'system_amount * 0,2'
          }
        ]
      )
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        amount_cents: 150_000
      )

      expect(card).to be_valid
      expect(card.custom_field_values).to include('comissao' => 300.0)
    end

    it 'calculates formulas that reference an earlier calculated field' do
      board = create(
        :kanban_board,
        custom_field_definitions: [
          { key: 'base', label: 'Base', field_type: 'decimal' },
          { key: 'subtotal', label: 'Subtotal', field_type: 'formula', formula: 'base * 2' },
          { key: 'total', label: 'Total', field_type: 'formula', formula: 'subtotal + 50' }
        ]
      )
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        custom_field_values: { base: 100 }
      )

      expect(card).to be_valid
      expect(card.custom_field_values).to include('subtotal' => 200.0, 'total' => 250.0)
    end

    it 'adds calendar days to a date formula in the account timezone' do
      board = create(
        :kanban_board,
        custom_field_definitions: [
          { key: 'inicio', label: 'Início', field_type: 'date' },
          {
            key: 'retorno', label: 'Retorno', field_type: 'formula',
            formula: 'add_days(inicio, 5)', formula_result_type: 'date'
          }
        ]
      )
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        custom_field_values: { inicio: '2026-10-30' }
      )

      expect(card).to be_valid
      expect(card.custom_field_values['retorno']).to eq('2026-11-04')
    end

    it 'calculates whole calendar days between two dates' do
      board = create(
        :kanban_board,
        custom_field_definitions: [
          { key: 'inicio', label: 'Início', field_type: 'date' },
          { key: 'fim', label: 'Fim', field_type: 'date' },
          {
            key: 'duracao', label: 'Duração', field_type: 'formula',
            formula: 'days_between(inicio, fim)', formula_result_type: 'number'
          }
        ]
      )
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        custom_field_values: { inicio: '2026-07-20', fim: '2026-07-25' }
      )

      expect(card).to be_valid
      expect(card.custom_field_values['duracao']).to eq(5.0)
    end

    it 'rejects a formula that references a later calculated field' do
      board = create(
        :kanban_board,
        custom_field_definitions: [
          { key: 'total', label: 'Total', field_type: 'formula', formula: 'subtotal + 50' },
          { key: 'subtotal', label: 'Subtotal', field_type: 'formula', formula: '100 * 2' }
        ]
      )
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage
      )

      expect(card).not_to be_valid
      expect(card.errors[:custom_field_values]).to include('total formula is invalid')
    end

    it 'resolves native opportunity identity and commercial fields for conditions' do
      conversation = create(:conversation)
      agent = create(:user, account: conversation.account)
      conversation.update!(assignee: agent)
      board = create(:kanban_board, account: conversation.account)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      card = build(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        conversation: conversation,
        contact: conversation.contact,
        inbox: conversation.inbox,
        owner: agent,
        subject: 'Plano empresarial',
        description: 'Venda pelo WhatsApp',
        amount_cents: 150_000,
        won_at: Time.zone.parse('2026-07-25 12:00:00')
      )

      expect(
        %w[
          system_subject system_description system_amount system_owner_id
          system_assignee_id system_stage_id system_inbox_id system_status
          system_contact_id system_conversation_id
        ].index_with { |key| card.send(:condition_field_value, key) }
      ).to eq(
        'system_subject' => 'Plano empresarial',
        'system_description' => 'Venda pelo WhatsApp',
        'system_amount' => BigDecimal(1500),
        'system_owner_id' => agent.id,
        'system_assignee_id' => agent.id,
        'system_stage_id' => stage.id,
        'system_inbox_id' => conversation.inbox_id,
        'system_status' => 'won',
        'system_contact_id' => conversation.contact_id,
        'system_conversation_id' => conversation.id
      )
    end

    it 'resolves native opportunity scheduling fields for conditions' do
      card = build(
        :kanban_card,
        starts_at: Time.zone.parse('2026-07-22 09:00:00'),
        due_at: Time.zone.parse('2026-07-23 17:00:00'),
        next_action_type: 'Enviar proposta',
        next_action_at: Time.zone.parse('2026-07-24 10:00:00'),
        next_action_note: 'Confirmar quantidade',
        next_action_completed_at: Time.zone.parse('2026-07-24 11:00:00'),
        lost_reason: 'Preço'
      )

      expect(
        %w[
          system_starts_at system_due_at system_next_action_type
          system_next_action_at system_next_action_note
          system_next_action_completed system_lost_reason
        ].index_with { |key| card.send(:condition_field_value, key) }
      ).to eq(
        'system_starts_at' => '2026-07-22',
        'system_due_at' => '2026-07-23',
        'system_next_action_type' => 'Enviar proposta',
        'system_next_action_at' => '2026-07-24',
        'system_next_action_note' => 'Confirmar quantidade',
        'system_next_action_completed' => true,
        'system_lost_reason' => 'Preço'
      )
    end

    it 'records a snapshot when the next action is completed' do
      card = create(
        :kanban_card,
        next_action_type: 'Enviar proposta',
        next_action_at: Time.zone.parse('2026-07-21 15:00:00 UTC'),
        next_action_note: 'Enviar no WhatsApp'
      )
      completed_at = Time.zone.parse('2026-07-21 16:00:00 UTC')

      card.update!(next_action_completed_at: completed_at)

      expect(card.next_action_history).to contain_exactly(
        {
          'type' => 'Enviar proposta',
          'scheduled_at' => '2026-07-21T15:00:00.000Z',
          'note' => 'Enviar no WhatsApp',
          'completed_at' => '2026-07-21T16:00:00.000Z'
        }
      )
    end

    it 'treats a completed next action as missing until another action is scheduled' do
      card = create(
        :kanban_card,
        next_action_at: 1.day.ago,
        next_action_completed_at: Time.current
      )

      expect(card.next_action_status).to eq(KanbanCard::NEXT_ACTION_STATUS_MISSING)
    end

    it 'clears completion when the next action is rescheduled' do
      card = create(
        :kanban_card,
        next_action_type: 'Cobrar retorno',
        next_action_at: 1.day.ago,
        next_action_completed_at: Time.current
      )

      card.update!(next_action_at: 2.days.from_now)

      expect(card.next_action_completed_at).to be_nil
      expect(card.next_action_status).to eq(KanbanCard::NEXT_ACTION_STATUS_FUTURE)
    end
  end

  describe 'labels' do
    it 'can receive labels through Labelable' do
      card = create(:kanban_card)

      card.update_labels(%w[hot enterprise])

      expect(card.reload.label_list).to match_array(%w[hot enterprise])
    end
  end

  describe 'validations' do
    it 'allows a valid manual card' do
      card = build(:kanban_card)

      expect(card).to be_valid
    end

    it 'allows a valid conversation card' do
      card = build(:kanban_card, :conversation_origin)

      expect(card).to be_valid
    end

    it 'allows a card without starts_at and due_at' do
      card = build(:kanban_card, starts_at: nil, due_at: nil)

      expect(card).to be_valid
    end

    it 'allows a card with only starts_at' do
      card = build(:kanban_card, starts_at: 1.day.from_now, due_at: nil)

      expect(card).to be_valid
    end

    it 'allows a card with only due_at' do
      card = build(:kanban_card, starts_at: nil, due_at: 1.day.from_now)

      expect(card).to be_valid
    end

    it 'allows a card with equal starts_at and due_at' do
      scheduled_at = 1.day.from_now
      card = build(:kanban_card, starts_at: scheduled_at, due_at: scheduled_at)

      expect(card).to be_valid
    end

    it 'allows a card with due_at after starts_at' do
      starts_at = 1.day.from_now
      card = build(:kanban_card, starts_at: starts_at, due_at: starts_at + 1.hour)

      expect(card).to be_valid
    end

    it 'rejects a card with due_at before starts_at' do
      starts_at = 1.day.from_now
      card = build(:kanban_card, starts_at: starts_at, due_at: starts_at - 1.hour)

      expect(card).not_to be_valid
      expect(card.errors[:due_at]).to include('must be greater than or equal to starts at')
    end

    it 'requires a subject for manual cards' do
      card = build(:kanban_card, subject: ' ')

      expect(card).not_to be_valid
      expect(card.errors[:subject]).to be_present
      expect(card.errors[:normalized_subject]).to be_present
    end

    it 'requires a conversation for conversation cards' do
      card = build(:kanban_card, origin: 'conversation', conversation: nil, subject: nil)

      expect(card).not_to be_valid
      expect(card.errors[:conversation]).to be_present
    end

    it 'trims manual subject' do
      card = build(:kanban_card, subject: '  Cotação Notebook  ')

      card.valid?

      expect(card.subject).to eq('Cotação Notebook')
    end

    it 'collapses internal subject spaces' do
      card = build(:kanban_card, subject: 'Cotação   Notebook')

      card.valid?

      expect(card.subject).to eq('Cotação Notebook')
    end

    it 'stores lowercase normalized subject' do
      card = build(:kanban_card, subject: '  Cotação   Notebook  ')

      card.valid?

      expect(card.normalized_subject).to eq('cotação notebook')
    end

    it 'rejects duplicate active manual cards' do
      existing_card = create(:kanban_card, subject: 'Cotação Notebook')
      card = build(
        :kanban_card,
        account: existing_card.account,
        kanban_board: existing_card.kanban_board,
        kanban_stage: existing_card.kanban_stage,
        contact: existing_card.contact,
        inbox: existing_card.inbox,
        subject: '  cotação   notebook  '
      )

      expect(card).not_to be_valid
      expect(card.errors[:normalized_subject]).to be_present
    end

    it 'allows manual cards for the same contact and inbox with different subjects' do
      existing_card = create(:kanban_card, subject: 'Cotação Notebook')
      card = build(
        :kanban_card,
        account: existing_card.account,
        kanban_board: existing_card.kanban_board,
        kanban_stage: existing_card.kanban_stage,
        contact: existing_card.contact,
        inbox: existing_card.inbox,
        subject: 'Cotação Monitor'
      )

      expect(card).to be_valid
    end

    it 'allows active manual card recreation when existing card is inactive' do
      existing_card = create(:kanban_card, active: false, subject: 'Cotação Notebook')
      card = build(
        :kanban_card,
        account: existing_card.account,
        kanban_board: existing_card.kanban_board,
        kanban_stage: existing_card.kanban_stage,
        contact: existing_card.contact,
        inbox: existing_card.inbox,
        subject: 'Cotação Notebook'
      )

      expect(card).to be_valid
    end

    it 'rejects duplicate active conversation cards with the same subject' do
      existing_card = create(:kanban_card, :conversation_origin, subject: 'Enterprise renewal')
      card = build(
        :kanban_card,
        :conversation_origin,
        account: existing_card.account,
        kanban_board: existing_card.kanban_board,
        kanban_stage: existing_card.kanban_stage,
        conversation: existing_card.conversation,
        subject: '  enterprise   renewal  '
      )

      expect(card).not_to be_valid
      expect(card.errors[:conversation_id]).to be_present
    end

    it 'allows conversation cards for the same conversation with different subjects' do
      existing_card = create(:kanban_card, :conversation_origin, subject: 'Enterprise renewal')
      card = build(
        :kanban_card,
        :conversation_origin,
        account: existing_card.account,
        kanban_board: existing_card.kanban_board,
        kanban_stage: existing_card.kanban_stage,
        conversation: existing_card.conversation,
        subject: 'Expansion project'
      )

      expect(card).to be_valid
    end

    it 'rejects conversation card recreation with the same subject when existing card is inactive' do
      existing_card = create(:kanban_card, :conversation_origin, active: false, subject: 'Enterprise renewal')
      card = build(
        :kanban_card,
        :conversation_origin,
        account: existing_card.account,
        kanban_board: existing_card.kanban_board,
        kanban_stage: existing_card.kanban_stage,
        conversation: existing_card.conversation,
        subject: 'Enterprise renewal'
      )

      expect(card).not_to be_valid
      expect(card.errors[:conversation_id]).to be_present
    end

    it 'allows the same conversation card in different boards' do
      existing_card = create(:kanban_card, :conversation_origin)
      other_board = create(:kanban_board, account: existing_card.account)
      other_stage = create(:kanban_stage, account: existing_card.account, kanban_board: other_board)
      card = build(
        :kanban_card,
        :conversation_origin,
        account: existing_card.account,
        kanban_board: other_board,
        kanban_stage: other_stage,
        conversation: existing_card.conversation
      )

      expect(card).to be_valid
    end

    it 'does not apply conversation uniqueness to manual cards' do
      conversation = create(:conversation)
      board = create(:kanban_board, account: conversation.account)
      stage = create(:kanban_stage, account: conversation.account, kanban_board: board)
      create(
        :kanban_card,
        account: conversation.account,
        kanban_board: board,
        kanban_stage: stage,
        contact: conversation.contact,
        inbox: conversation.inbox,
        conversation: conversation,
        subject: 'First opportunity'
      )
      card = build(
        :kanban_card,
        account: conversation.account,
        kanban_board: board,
        kanban_stage: stage,
        contact: conversation.contact,
        inbox: conversation.inbox,
        conversation: conversation,
        subject: 'Second opportunity'
      )

      expect(card).to be_valid
    end

    it 'blocks duplicate historical conversation cards with the same subject at the database index' do
      existing_card = create(:kanban_card, :conversation_origin, subject: 'Enterprise renewal')
      duplicate_attributes = existing_card.attributes.slice(
        'account_id',
        'kanban_board_id',
        'kanban_stage_id',
        'contact_id',
        'inbox_id',
        'conversation_id',
        'normalized_subject',
        'origin'
      ).merge(
        'subject' => 'Enterprise renewal',
        'position' => existing_card.position + 1,
        'active' => false,
        'stage_entered_at' => Time.current,
        'created_at' => Time.current,
        'updated_at' => Time.current
      )

      expect do
        described_class.insert_all!([duplicate_attributes]) # rubocop:disable Rails/SkipsModelValidations
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'rejects a stage from another board' do
      board = create(:kanban_board)
      other_board = create(:kanban_board, account: board.account)
      other_stage = create(:kanban_stage, account: board.account, kanban_board: other_board)
      card = build(:kanban_card, account: board.account, kanban_board: board, kanban_stage: other_stage)

      expect(card).not_to be_valid
      expect(card.errors[:kanban_stage]).to be_present
    end

    it 'rejects a board from another account' do
      card = build(:kanban_card)
      card.kanban_board = create(:kanban_board)

      expect(card).not_to be_valid
      expect(card.errors[:kanban_board]).to be_present
    end

    it 'rejects a stage from another account' do
      card = build(:kanban_card)
      card.kanban_stage = create(:kanban_stage)

      expect(card).not_to be_valid
      expect(card.errors[:kanban_stage]).to be_present
    end

    it 'rejects a contact from another account' do
      card = build(:kanban_card)
      card.contact = create(:contact)

      expect(card).not_to be_valid
      expect(card.errors[:contact]).to be_present
    end

    it 'rejects an inbox from another account' do
      card = build(:kanban_card)
      card.inbox = create(:inbox)

      expect(card).not_to be_valid
      expect(card.errors[:inbox]).to be_present
    end

    it 'rejects an optional conversation from another account' do
      card = build(:kanban_card)
      card.conversation = create(:conversation)

      expect(card).not_to be_valid
      expect(card.errors[:conversation]).to be_present
    end

    it 'rejects an optional conversation with another contact' do
      conversation = create(:conversation)
      card = build(
        :kanban_card,
        account: conversation.account,
        conversation: conversation,
        contact: create(:contact, account: conversation.account),
        inbox: conversation.inbox
      )

      expect(card).not_to be_valid
      expect(card.errors[:conversation]).to be_present
    end

    it 'rejects an optional conversation with another inbox' do
      conversation = create(:conversation)
      card = build(
        :kanban_card,
        account: conversation.account,
        conversation: conversation,
        contact: conversation.contact,
        inbox: create(:inbox, account: conversation.account)
      )

      expect(card).not_to be_valid
      expect(card.errors[:conversation]).to be_present
    end
  end

  describe '.active' do
    it 'returns only active cards' do
      active_card = create(:kanban_card, active: true)
      create(:kanban_card, active: false)

      expect(described_class.active.ids).to contain_exactly(active_card.id)
    end
  end

  describe '.ordered' do
    it 'orders by position, creation time, and id' do
      newer_card = create(:kanban_card, position: 2, created_at: 1.day.ago)
      earlier_card = create(:kanban_card, position: 1, created_at: 2.days.ago)
      first_duplicate = create(:kanban_card, position: 1, created_at: 1.day.ago)
      second_duplicate = create(:kanban_card, position: 1, created_at: 1.day.ago)

      expect(described_class.ordered.ids).to eq([earlier_card.id, first_duplicate.id, second_duplicate.id, newer_card.id])
    end
  end

  describe '.normalize_positions_for_stage!' do
    it 'assigns sequential positions to active cards ordered by position, creation time, and id' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      later_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 2)
      first_duplicate = create(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        position: 1,
        created_at: 2.days.ago
      )
      second_duplicate = create(
        :kanban_card,
        account: board.account,
        kanban_board: board,
        kanban_stage: stage,
        position: 1,
        created_at: 1.day.ago
      )

      described_class.normalize_positions_for_stage!(kanban_board: board, kanban_stage: stage)

      expect(first_duplicate.reload.position).to eq(1)
      expect(second_duplicate.reload.position).to eq(2)
      expect(later_card.reload.position).to eq(3)
    end

    it 'excludes inactive cards' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      inactive_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1, active: false)
      active_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 10)

      described_class.normalize_positions_for_stage!(kanban_board: board, kanban_stage: stage)

      expect(active_card.reload.position).to eq(1)
      expect(inactive_card.reload.position).to eq(1)
    end

    it 'updates updated_at only for active cards whose positions change' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      original_time = 2.days.ago
      unchanged_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1, updated_at: original_time)
      changed_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 10, updated_at: original_time)
      inactive_card = create(
        :kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 2, active: false, updated_at: original_time
      )

      travel_to(Time.zone.parse('2026-01-01 12:00:00 UTC')) do
        described_class.normalize_positions_for_stage!(kanban_board: board, kanban_stage: stage)
      end

      expect(unchanged_card.reload.updated_at.to_i).to eq(original_time.to_i)
      expect(changed_card.reload.updated_at.to_i).to eq(Time.zone.parse('2026-01-01 12:00:00 UTC').to_i)
      expect(inactive_card.reload.updated_at.to_i).to eq(original_time.to_i)
    end

    it 'does not query taggings while normalizing positions' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 10)
      create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 20)

      sql_queries = collect_sql_queries do
        described_class.normalize_positions_for_stage!(kanban_board: board, kanban_stage: stage)
      end

      expect(labels_tags_taggings_query_count(sql_queries)).to eq(0)
    end

    it 'does not touch cards from other boards' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      other_board = create(:kanban_board, account: board.account)
      other_stage = create(:kanban_stage, account: board.account, kanban_board: other_board)
      card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 10)
      other_board_card = create(:kanban_card, account: board.account, kanban_board: other_board, kanban_stage: other_stage, position: 10)

      described_class.normalize_positions_for_stage!(kanban_board: board, kanban_stage: stage)

      expect(card.reload.position).to eq(1)
      expect(other_board_card.reload.position).to eq(10)
    end

    it 'does not touch cards from other stages' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      other_stage = create(:kanban_stage, account: board.account, kanban_board: board)
      card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 10)
      other_stage_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: other_stage, position: 10)

      described_class.normalize_positions_for_stage!(kanban_board: board, kanban_stage: stage)

      expect(card.reload.position).to eq(1)
      expect(other_stage_card.reload.position).to eq(10)
    end
  end

  describe 'sales opportunity status' do
    it 'treats active cards without close timestamps as open opportunities' do
      card = build(:kanban_card)

      expect(card).to be_open_opportunity
    end

    it 'does not treat won cards as open opportunities' do
      card = build(:kanban_card, won_at: Time.current)

      expect(card).not_to be_open_opportunity
    end

    it 'does not treat lost cards as open opportunities' do
      card = build(:kanban_card, lost_at: Time.current, lost_reason: 'Sem resposta')

      expect(card).not_to be_open_opportunity
    end

    it 'rejects cards marked as won and lost at the same time' do
      card = build(:kanban_card, won_at: Time.current, lost_at: Time.current, lost_reason: 'Preço')

      expect(card).not_to be_valid
      expect(card.errors[:base]).to include('cannot be marked as won and lost at the same time')
    end

    it 'requires a lost reason when marked as lost' do
      card = build(:kanban_card, lost_at: Time.current, lost_reason: nil)

      expect(card).not_to be_valid
      expect(card.errors[:lost_reason]).to include("can't be blank")
    end
  end

  describe '#next_action_status' do
    it 'returns missing for open cards without a next action' do
      card = build(:kanban_card, next_action_at: nil)

      expect(card.next_action_status(now: Time.zone.parse('2026-07-20 12:00:00'))).to eq('missing')
    end

    it 'returns overdue for open cards with next action before today' do
      card = build(:kanban_card, next_action_at: Time.zone.parse('2026-07-19 23:59:00'))

      expect(card.next_action_status(now: Time.zone.parse('2026-07-20 12:00:00'))).to eq('overdue')
    end

    it 'returns due_today for open cards with next action today' do
      card = build(:kanban_card, next_action_at: Time.zone.parse('2026-07-20 08:00:00'))

      expect(card.next_action_status(now: Time.zone.parse('2026-07-20 12:00:00'))).to eq('due_today')
    end

    it 'returns future for open cards with next action after today' do
      card = build(:kanban_card, next_action_at: Time.zone.parse('2026-07-21 08:00:00'))

      expect(card.next_action_status(now: Time.zone.parse('2026-07-20 12:00:00'))).to eq('future')
    end

    it 'returns closed for won cards' do
      card = build(:kanban_card, won_at: Time.zone.parse('2026-07-20 09:00:00'), next_action_at: nil)

      expect(card.next_action_status(now: Time.zone.parse('2026-07-20 12:00:00'))).to eq('closed')
    end
  end

  describe '#reorder_to_position!' do
    it 'reorders cards within the same stage' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      first_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1)
      second_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 2)
      third_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 3)

      third_card.reorder_to_position!(kanban_stage: stage, position: 1)

      expect(stage_positions(stage)).to eq([third_card.id, first_card.id, second_card.id])
    end

    it 'clamps same-stage positions below the minimum' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      first_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1)
      second_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 2)

      second_card.reorder_to_position!(kanban_stage: stage, position: 0)

      expect(stage_positions(stage)).to eq([second_card.id, first_card.id])
    end

    it 'clamps same-stage positions above the maximum' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      first_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1)
      second_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 2)

      first_card.reorder_to_position!(kanban_stage: stage, position: 10)

      expect(stage_positions(stage)).to eq([second_card.id, first_card.id])
    end

    it 'reorders cards across stages' do
      board = create(:kanban_board)
      source_stage = create(:kanban_stage, account: board.account, kanban_board: board)
      target_stage = create(:kanban_stage, account: board.account, kanban_board: board)
      moved_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: source_stage, position: 1)
      target_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: target_stage, position: 1)

      moved_card.reorder_to_position!(kanban_stage: target_stage, position: 1)

      expect(stage_positions(source_stage)).to eq([])
      expect(stage_positions(target_stage)).to eq([moved_card.id, target_card.id])
      expect(moved_card.reload.kanban_stage).to eq(target_stage)
    end

    it 'normalizes the source stage after a cross-stage move' do
      board = create(:kanban_board)
      source_stage = create(:kanban_stage, account: board.account, kanban_board: board)
      target_stage = create(:kanban_stage, account: board.account, kanban_board: board)
      moved_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: source_stage, position: 1)
      remaining_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: source_stage, position: 10)

      moved_card.reorder_to_position!(kanban_stage: target_stage, position: 1)

      expect(remaining_card.reload.position).to eq(1)
    end

    it 'normalizes the destination stage after a cross-stage move' do
      board = create(:kanban_board)
      source_stage = create(:kanban_stage, account: board.account, kanban_board: board)
      target_stage = create(:kanban_stage, account: board.account, kanban_board: board)
      moved_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: source_stage, position: 1)
      first_target_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: target_stage, position: 10)
      second_target_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: target_stage, position: 20)

      moved_card.reorder_to_position!(kanban_stage: target_stage, position: 2)

      expect(first_target_card.reload.position).to eq(1)
      expect(moved_card.reload.position).to eq(2)
      expect(second_target_card.reload.position).to eq(3)
    end

    it 'rejects reordering inactive cards' do
      card = create(:kanban_card, active: false, position: 10)

      expect do
        card.reorder_to_position!(kanban_stage: card.kanban_stage, position: 1)
      end.to raise_error(ActiveRecord::RecordNotSaved, 'Inactive kanban cards cannot be reordered')
      expect(card.reload.position).to eq(10)
    end

    it 'keeps soft-deleted card positions unchanged when active cards reorder' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      inactive_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1, active: false)
      first_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 2)
      second_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 3)

      second_card.reorder_to_position!(kanban_stage: stage, position: 1)

      expect(stage_positions(stage)).to eq([second_card.id, first_card.id])
      expect(inactive_card.reload.position).to eq(1)
    end

    it 'reorders manual cards and conversation cards identically' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      manual_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1)
      conversation = create(:conversation, account: board.account)
      conversation_card = create(
        :kanban_card,
        :conversation_origin,
        kanban_board: board,
        kanban_stage: stage,
        conversation: conversation,
        position: 2
      )

      conversation_card.reorder_to_position!(kanban_stage: stage, position: 1)
      expect(stage_positions(stage)).to eq([conversation_card.id, manual_card.id])

      manual_card.reorder_to_position!(kanban_stage: stage, position: 1)
      expect(stage_positions(stage)).to eq([manual_card.id, conversation_card.id])
    end

    it 'updates updated_at for mechanically reordered rows' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      first_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1, updated_at: 2.days.ago)
      second_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 2, updated_at: 2.days.ago)

      travel_to(Time.zone.parse('2026-01-01 12:00:00 UTC')) do
        second_card.reorder_to_position!(kanban_stage: stage, position: 1)
      end

      expect(first_card.reload.updated_at.to_i).to eq(Time.zone.parse('2026-01-01 12:00:00 UTC').to_i)
      expect(second_card.reload.updated_at.to_i).to eq(Time.zone.parse('2026-01-01 12:00:00 UTC').to_i)
    end

    it 'does not query taggings while reordering positions' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      first_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1)
      second_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 2)
      first_card.update_labels(%w[hot])
      second_card.update_labels(%w[warm])

      sql_queries = collect_sql_queries do
        second_card.reorder_to_position!(kanban_stage: stage, position: 1)
      end

      expect(labels_tags_taggings_query_count(sql_queries)).to eq(0)
    end

    it 'deactivates and normalizes remaining active cards' do
      board = create(:kanban_board)
      stage = create(:kanban_stage, account: board.account, kanban_board: board)
      first_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 1)
      second_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 5)
      inactive_card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage, position: 20, active: false)

      first_card.deactivate_and_normalize!

      expect(first_card.reload).not_to be_active
      expect(second_card.reload.position).to eq(1)
      expect(inactive_card.reload.position).to eq(20)
    end

    def stage_positions(stage)
      described_class.where(kanban_stage: stage).active.ordered.pluck(:id)
    end
  end

  def collect_sql_queries(&)
    sql_queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == 'SCHEMA'
      next if payload[:sql].blank?

      sql_queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &)
    sql_queries
  end

  def labels_tags_taggings_query_count(sql_queries)
    sql_queries.count do |sql|
      sql.match?(/FROM "labels"|JOIN "labels"|FROM "tags"|JOIN "tags"|FROM "taggings"|JOIN "taggings"/)
    end
  end
end
