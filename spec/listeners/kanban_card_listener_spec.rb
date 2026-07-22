require 'rails_helper'

RSpec.describe KanbanCardListener do
  let(:listener) { described_class.instance }
  let(:conversation) { create(:conversation) }
  let(:event_name) { :'conversation.created' }

  describe '#conversation_created' do
    it 'enqueues automatic card creation with the conversation id' do
      event = Events::Base.new(event_name, Time.zone.now, conversation: conversation)

      expect { listener.conversation_created(event) }.to have_enqueued_job(KanbanCards::AutoCreateFromConversationJob)
        .with(conversation.id)
        .on_queue('low')
    end

    it 'does not enqueue when the conversation payload is missing' do
      event = Events::Base.new(event_name, Time.zone.now, {})

      expect { listener.conversation_created(event) }.not_to have_enqueued_job(KanbanCards::AutoCreateFromConversationJob)
    end
  end

  describe '#kanban_card_stage_changed' do
    it 'enqueues matching commercial rules with the immutable event id' do
      card = create(:kanban_card)
      rule = create(
        :kanban_automation_rule,
        account: card.account,
        kanban_board: card.kanban_board,
        event_name: Events::Types::KANBAN_CARD_STAGE_CHANGED
      )
      event = Events::Base.new(
        Events::Types::KANBAN_CARD_STAGE_CHANGED,
        Time.zone.now,
        account_id: card.account_id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        event_id: 123
      )

      expect do
        listener.kanban_card_stage_changed(event)
      end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob).with(
        rule.id,
        Events::Types::KANBAN_CARD_STAGE_CHANGED,
        123,
        card.id,
        123
      ).on_queue('critical')
    end
  end

  describe '#message_created' do
    it 'pauses an active cadence after an incoming customer message' do
      conversation = create(:conversation)
      card = create(:kanban_card, :conversation_origin, conversation: conversation)
      cadence = create(:kanban_cadence, account: card.account, kanban_board: card.kanban_board)
      enrollment = create(
        :kanban_cadence_enrollment,
        account: card.account,
        kanban_board: card.kanban_board,
        kanban_card: card,
        kanban_cadence: cadence
      )
      independent_cadence = create(
        :kanban_cadence,
        account: card.account,
        kanban_board: card.kanban_board,
        pause_on_incoming_message: false
      )
      independent_enrollment = create(
        :kanban_cadence_enrollment,
        account: card.account,
        kanban_board: card.kanban_board,
        kanban_card: card,
        kanban_cadence: independent_cadence
      )
      message = create(
        :message,
        conversation: conversation,
        account: conversation.account,
        inbox: conversation.inbox
      )

      event = Events::Base.new(Events::Types::MESSAGE_CREATED, Time.zone.now, message: message)
      listener.message_created(event)

      expect(enrollment.reload).to be_paused
      expect(enrollment.last_error).to include('incoming customer message')
      expect(independent_enrollment.reload).to be_active
    end
  end

  describe '#kanban_card_next_action_completed' do
    it 'schedules the next cadence step after completion' do
      card = create(:kanban_card)
      cadence = create(
        :kanban_cadence,
        account: card.account,
        kanban_board: card.kanban_board,
        steps: [
          { delay_hours: 0, action_type: 'First call' },
          { delay_hours: 24, action_type: 'Second call' }
        ]
      )
      enrollment = create(
        :kanban_cadence_enrollment,
        account: card.account,
        kanban_board: card.kanban_board,
        kanban_card: card,
        kanban_cadence: cadence,
        status: 'awaiting_completion',
        next_run_at: nil
      )
      event = Events::Base.new(
        Events::Types::KANBAN_CARD_NEXT_ACTION_COMPLETED,
        Time.zone.now,
        account_id: card.account_id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        event_type: 'next_action_completed'
      )

      listener.kanban_card_next_action_completed(event)

      expect(enrollment.reload).to be_active
      expect(enrollment.current_step).to eq(1)
      expect(enrollment.next_run_at).to be_within(1.minute).of(24.hours.from_now)
    end
  end

  describe 'async dispatcher registration' do
    it 'registers the Kanban listener' do
      expect(async_listener_classes).to include(described_class)
    end

    it 'keeps existing async listeners registered' do
      expect(async_listener_classes).to include(
        AutomationRuleListener,
        CampaignListener,
        CsatSurveyListener,
        HookListener,
        InstallationWebhookListener,
        NotificationListener,
        ParticipationListener,
        Conversations::UnreadCounts::Listener,
        ReportingEventListener,
        WebhookListener
      )
    end
  end

  def async_listener_classes
    AsyncDispatcher.new.listeners.map(&:class)
  end
end
