# frozen_string_literal: true

module Events::Types
  ### Installation Events ###
  # account events
  ACCOUNT_CREATED = 'account.created'
  ACCOUNT_CACHE_INVALIDATED = 'account.cache_invalidated'

  #### Account Events ###
  # campaign events
  CAMPAIGN_TRIGGERED = 'campaign.triggered'

  # channel events
  WEBWIDGET_TRIGGERED = 'webwidget.triggered'

  # conversation events
  CONVERSATION_CREATED = 'conversation.created'
  CONVERSATION_UPDATED = 'conversation.updated'
  CONVERSATION_DELETED = 'conversation.deleted'
  CONVERSATION_READ = 'conversation.read'
  CONVERSATION_BOT_HANDOFF = 'conversation.bot_handoff'
  # FIXME: deprecate the opened and resolved events in future in favor of status changed event.
  CONVERSATION_OPENED = 'conversation.opened'
  CONVERSATION_RESOLVED = 'conversation.resolved'
  CONVERSATION_CAPTAIN_INFERENCE_RESOLVED = 'conversation.captain_inference_resolved'
  CONVERSATION_CAPTAIN_INFERENCE_HANDOFF = 'conversation.captain_inference_handoff'

  CONVERSATION_STATUS_CHANGED = 'conversation.status_changed'
  CONVERSATION_CONTACT_CHANGED = 'conversation.contact_changed'
  CONVERSATION_UNREAD_COUNT_CHANGED = 'conversation.unread_count_changed'
  ASSIGNEE_CHANGED = 'assignee.changed'
  TEAM_CHANGED = 'team.changed'
  CONVERSATION_TYPING_ON = 'conversation.typing_on'
  CONVERSATION_TYPING_OFF = 'conversation.typing_off'
  CONVERSATION_MENTIONED = 'conversation.mentioned'

  # message events
  MESSAGE_CREATED = 'message.created'
  FIRST_REPLY_CREATED = 'first.reply.created'
  REPLY_CREATED = 'reply.created'
  MESSAGE_UPDATED = 'message.updated'

  # contact events
  CONTACT_CREATED = 'contact.created'
  CONTACT_UPDATED = 'contact.updated'
  CONTACT_MERGED = 'contact.merged'
  CONTACT_DELETED = 'contact.deleted'

  # contact events
  INBOX_CREATED = 'inbox.created'
  INBOX_UPDATED = 'inbox.updated'

  # notification events
  NOTIFICATION_CREATED = 'notification.created'
  NOTIFICATION_DELETED = 'notification.deleted'
  NOTIFICATION_UPDATED = 'notification.updated'

  # agent events
  AGENT_ADDED = 'agent.added'
  AGENT_REMOVED = 'agent.removed'

  # copilot events
  COPILOT_MESSAGE_CREATED = 'copilot.message.created'

  # kanban events
  KANBAN_BOARD_UPDATED = 'kanban.board.updated'
  KANBAN_STAGE_CREATED = 'kanban.stage.created'
  KANBAN_STAGE_UPDATED = 'kanban.stage.updated'
  KANBAN_STAGE_DELETED = 'kanban.stage.deleted'
  KANBAN_STAGE_REORDERED = 'kanban.stage.reordered'
  KANBAN_CARD_CREATED = 'kanban.card.created'
  KANBAN_CARD_UPDATED = 'kanban.card.updated'
  KANBAN_CARD_DELETED = 'kanban.card.deleted'
  KANBAN_CARD_REORDERED = 'kanban.card.reordered'
  KANBAN_CARD_STAGE_CHANGED = 'kanban.card.stage_changed'
  KANBAN_CARD_OWNER_CHANGED = 'kanban.card.owner_changed'
  KANBAN_CARD_AMOUNT_CHANGED = 'kanban.card.amount_changed'
  KANBAN_CARD_CUSTOM_FIELDS_CHANGED = 'kanban.card.custom_fields_changed'
  KANBAN_CARD_FIELDS_CHANGED = 'kanban.card.fields_changed'
  KANBAN_CARD_NEXT_ACTION_SCHEDULED = 'kanban.card.next_action_scheduled'
  KANBAN_CARD_NEXT_ACTION_COMPLETED = 'kanban.card.next_action_completed'
  KANBAN_CARD_NEXT_ACTION_OVERDUE = 'kanban.card.next_action_overdue'
  KANBAN_CARD_WON = 'kanban.card.won'
  KANBAN_CARD_LOST = 'kanban.card.lost'
  KANBAN_CARD_REOPENED = 'kanban.card.reopened'
  KANBAN_CARD_ARCHIVED = 'kanban.card.archived'
  KANBAN_CARD_RESTORED = 'kanban.card.restored'
  KANBAN_CARD_MANUAL_STARTED = 'kanban.card.manual_started'
  KANBAN_CARD_CUSTOMER_MESSAGE_RECEIVED = 'kanban.card.customer_message_received'
  KANBAN_CARD_WEBHOOK_RECEIVED = 'kanban.card.webhook_received'
  KANBAN_APPOINTMENT_CREATED = 'kanban.appointment.created'
  KANBAN_APPOINTMENT_RESCHEDULED = 'kanban.appointment.rescheduled'
  KANBAN_APPOINTMENT_CANCELED = 'kanban.appointment.canceled'
  KANBAN_APPOINTMENT_CONFIRMED = 'kanban.appointment.confirmed'
  KANBAN_APPOINTMENT_COMPLETED = 'kanban.appointment.completed'
  KANBAN_APPOINTMENT_NO_SHOW = 'kanban.appointment.no_show'
  FINANCE_PAYMENT_CREATED = 'finance.payment.created'
  FINANCE_PAYMENT_OVERDUE = 'finance.payment.overdue'
  FINANCE_PAYMENT_CONFIRMED = 'finance.payment.confirmed'
  FINANCE_PAYMENT_RECEIVED = 'finance.payment.received'
  FINANCE_PAYMENT_CANCELED = 'finance.payment.canceled'
  FINANCE_PAYMENT_REFUNDED = 'finance.payment.refunded'
  FINANCE_PAYMENT_CHARGEBACK = 'finance.payment.chargeback'
  FORMS_INVITATION_SENT = 'forms.invitation.sent'
  FORMS_INVITATION_OPENED = 'forms.invitation.opened'
  FORMS_INVITATION_EXPIRED = 'forms.invitation.expired'
  FORMS_INVITATION_ABANDONED = 'forms.invitation.abandoned'
  FORMS_SUBMISSION_CRITICAL = 'forms.submission.critical'
  FORMS_SUBMISSION_COMPLETED = 'forms.submission.completed'
end
