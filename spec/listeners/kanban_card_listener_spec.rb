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

  describe '#kanban_card_created' do
    it 'enqueues a stage rule that also listens to opportunities created in that stage' do
      card = create(:kanban_card)
      rule = create(
        :kanban_automation_rule,
        account: card.account,
        kanban_board: card.kanban_board,
        event_name: Events::Types::KANBAN_CARD_STAGE_CHANGED,
        conditions: {
          stage_ids: [card.kanban_stage_id],
          trigger_event_names: [
            Events::Types::KANBAN_CARD_CREATED,
            Events::Types::KANBAN_CARD_STAGE_CHANGED
          ]
        }
      )
      event = Events::Base.new(
        Events::Types::KANBAN_CARD_CREATED,
        Time.zone.now,
        account_id: card.account_id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        event_id: 124
      )

      expect do
        listener.kanban_card_created(event)
      end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob).with(
        rule.id,
        Events::Types::KANBAN_CARD_CREATED,
        124,
        card.id,
        124
      ).on_queue('critical')
    end
  end

  describe '#finance_payment_received' do
    it 'enqueues the matching workflow with safe payment context' do
      card = create(:kanban_card)
      rule = create(
        :kanban_automation_rule,
        account: card.account,
        kanban_board: card.kanban_board,
        event_name: Events::Types::FINANCE_PAYMENT_RECEIVED
      )
      event = Events::Base.new(
        Events::Types::FINANCE_PAYMENT_RECEIVED,
        Time.zone.now,
        account_id: card.account_id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        payment_id: 42,
        payment_status: 'received',
        payment_amount_cents: 15_025,
        payment_currency: 'BRL',
        event_key: 'finance-payment:42:event:evt_001'
      )

      expect do
        listener.finance_payment_received(event)
      end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob).with(
        rule.id,
        Events::Types::FINANCE_PAYMENT_RECEIVED,
        'finance-payment:42:event:evt_001',
        card.id,
        {
          event_data: hash_including(
            payment_id: 42,
            payment_status: 'received',
            payment_amount_cents: 15_025,
            payment_currency: 'BRL'
          )
        }
      ).on_queue('critical')
    end
  end

  describe '#forms_submission_completed' do
    it 'enqueues the matching workflow without exposing form answers' do
      card = create(:kanban_card)
      rule = create(
        :kanban_automation_rule,
        account: card.account,
        kanban_board: card.kanban_board,
        event_name: Events::Types::FORMS_SUBMISSION_COMPLETED
      )
      event = Events::Base.new(
        Events::Types::FORMS_SUBMISSION_COMPLETED,
        Time.zone.now,
        account_id: card.account_id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        form_submission_id: 41,
        form_template_id: 12,
        event_key: 'forms-submission:41:completed'
      )

      expect do
        listener.forms_submission_completed(event)
      end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob).with(
        rule.id,
        Events::Types::FORMS_SUBMISSION_COMPLETED,
        'forms-submission:41:completed',
        card.id,
        {
          event_data: hash_including(
            form_submission_id: 41,
            form_template_id: 12
          )
        }
      ).on_queue('critical')
    end
  end

  describe '#forms_invitation_sent' do
    it 'enqueues the matching workflow without exposing the invitation link' do
      card = create(:kanban_card)
      rule = create(
        :kanban_automation_rule,
        account: card.account,
        kanban_board: card.kanban_board,
        event_name: Events::Types::FORMS_INVITATION_SENT
      )
      event = Events::Base.new(
        Events::Types::FORMS_INVITATION_SENT,
        Time.zone.now,
        account_id: card.account_id,
        board_id: card.kanban_board_id,
        card_id: card.id,
        form_invitation_id: 41,
        form_template_id: 12,
        event_key: 'forms-invitation:41:sent'
      )

      expect do
        listener.forms_invitation_sent(event)
      end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob).with(
        rule.id,
        Events::Types::FORMS_INVITATION_SENT,
        'forms-invitation:41:sent',
        card.id,
        {
          event_data: hash_including(
            form_invitation_id: 41,
            form_template_id: 12
          )
        }
      ).on_queue('critical')
    end
  end

  describe '#message_created' do
    it 'records a form invitation when its link is sent in an outgoing message' do
      message = create(:message, message_type: :outgoing)
      event = Events::Base.new(Events::Types::MESSAGE_CREATED, Time.zone.now, message: message)
      service = instance_double(Forms::MarkInvitationSentService, perform!: nil)
      allow(Forms::MarkInvitationSentService).to receive(:new).with(message: message).and_return(service)

      listener.message_created(event)

      expect(service).to have_received(:perform!)
    end

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

    it 'resumes response waits and triggers matching customer-message rules' do
      conversation = create(:conversation)
      card = create(:kanban_card, :conversation_origin, conversation: conversation)
      rule = create(
        :kanban_automation_rule,
        account: card.account,
        kanban_board: card.kanban_board,
        event_name: Events::Types::KANBAN_CARD_CUSTOMER_MESSAGE_RECEIVED
      )
      execution = create(
        :kanban_automation_execution,
        account: card.account,
        kanban_automation_rule: rule,
        kanban_card: card,
        status: 'waiting',
        scheduled_at: 1.day.from_now,
        workflow_state: {
          'next_node_id' => 'end',
          'timeout_node_id' => 'expired',
          'waiting_for' => 'customer_message'
        }
      )
      message = create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox)
      event = Events::Base.new(Events::Types::MESSAGE_CREATED, Time.zone.now, message: message)

      expect do
        listener.message_created(event)
      end.to have_enqueued_job(KanbanAutomations::ContinueWorkflowJob)
        .with(execution.id, card.id)
        .and have_enqueued_job(KanbanAutomations::ExecuteRuleJob)
        .with(
          rule.id,
          Events::Types::KANBAN_CARD_CUSTOMER_MESSAGE_RECEIVED,
          "message:#{message.id}:card:#{card.id}",
          card.id,
          { event_data: { customer_message_content: message.content.to_s } }
        )

      expect(execution.reload).to have_attributes(scheduled_at: nil)
      expect(execution.workflow_state).not_to have_key('waiting_for')
      expect(execution.workflow_state).not_to have_key('timeout_node_id')
    end

    it 'skips inactivity waits when the customer responds before the timeout' do
      conversation = create(:conversation)
      card = create(:kanban_card, :conversation_origin, conversation: conversation)
      rule = create(
        :kanban_automation_rule,
        account: card.account,
        kanban_board: card.kanban_board
      )
      execution = create(
        :kanban_automation_execution,
        account: card.account,
        kanban_automation_rule: rule,
        kanban_card: card,
        status: 'waiting',
        scheduled_at: 1.day.from_now,
        workflow_state: { 'next_node_id' => 'end', 'waiting_for' => 'customer_inactivity' }
      )
      message = create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox)
      event = Events::Base.new(Events::Types::MESSAGE_CREATED, Time.zone.now, message: message)

      listener.message_created(event)

      expect(execution.reload).to have_attributes(status: 'skipped', scheduled_at: nil)
      expect(execution.workflow_state).to eq({})
      expect(execution.action_results).to include(
        hash_including('reason' => 'customer_message_received', 'waiting_for' => 'customer_inactivity')
      )
    end

    it 'continues through the response path when a routed inactivity wait receives a message' do
      conversation = create(:conversation)
      card = create(:kanban_card, :conversation_origin, conversation: conversation)
      rule = create(
        :kanban_automation_rule,
        account: card.account,
        kanban_board: card.kanban_board
      )
      execution = create(
        :kanban_automation_execution,
        account: card.account,
        kanban_automation_rule: rule,
        kanban_card: card,
        status: 'waiting',
        scheduled_at: 1.day.from_now,
        workflow_state: {
          'next_node_id' => 'idle',
          'response_node_id' => 'responded',
          'waiting_for' => 'customer_inactivity'
        }
      )
      message = create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox)
      event = Events::Base.new(Events::Types::MESSAGE_CREATED, Time.zone.now, message: message)

      expect do
        listener.message_created(event)
      end.to have_enqueued_job(KanbanAutomations::ContinueWorkflowJob)
        .with(execution.id, card.id)

      expect(execution.reload).to have_attributes(status: 'waiting', scheduled_at: nil)
      expect(execution.workflow_state).to eq('next_node_id' => 'responded')
      expect(execution.action_results).to include(
        hash_including('reason' => 'customer_message_received', 'waiting_for' => 'customer_inactivity')
      )
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
