class RaevoAi::HandoffExecutor
  def initialize(integration:, conversation:, action_id:, reason:, note:)
    @integration = integration
    @conversation = conversation
    @action_id = action_id
    @reason = reason
    @note = note
  end

  def perform
    context = RaevoAi::HandoffContext.new(integration: @integration, conversation: @conversation).payload
    claim = RaevoAi::CommandRecorder.new(
      integration: @integration,
      action_id: @action_id,
      command_type: 'handoff.apply',
      payload: command_payload(context)
    ).claim

    return claim.command.result if claim.command.state == 'applied'

    RaevoAiCommand.transaction do
      command = claim.command.lock!
      if command.state == 'applied'
        command.result
      else
        apply_handoff(command, context)
      end
    end
  end

  private

  def command_payload(context)
    {
      'conversation_id' => context['conversation_id'],
      'reason' => @reason,
      'note' => @note,
      'handoff_team_id' => context['handoff_team_id'],
      'handoff_assignee_id' => context['handoff_assignee_id']
    }
  end

  def apply_handoff(command, context)
    apply_assignment!(context)
    @conversation.add_labels(context['handoff_labels'])
    note_message = Messages::MessageBuilder.new(nil, @conversation.reload, private_note_params).perform
    result = receipt(context, note_message)

    command.update!(state: 'applied', result: result)
    result
  end

  def apply_assignment!(context)
    if context['handoff_team_id'].present?
      @conversation.update!(team_id: context['handoff_team_id'], assignee_id: nil)
    else
      @conversation.update!(team_id: nil)
      Conversations::AssignmentService.new(
        conversation: @conversation,
        assignee_id: context['handoff_assignee_id']
      ).perform
    end
  end

  def private_note_params
    {
      content: "[ELIS — handoff]\nMotivo: #{@reason}\n\n#{@note}",
      private: true,
      content_attributes: { 'raevo_ai_action_id' => @action_id }
    }
  end

  def receipt(context, note_message)
    {
      'action_id' => @action_id,
      'status' => 'applied',
      'handoff_applied' => true,
      'receipts' => {
        'assignment' => assignment_receipt(context),
        'labels' => { 'status' => 'applied', 'added' => context['handoff_labels'] },
        'note' => { 'status' => 'applied', 'note_id' => note_message.id }
      }
    }
  end

  def assignment_receipt(context)
    assignment = { 'status' => 'applied' }
    assignment['team_id'] = context['handoff_team_id'] if context['handoff_team_id'].present?
    assignment['assignee_id'] = context['handoff_assignee_id'] if context['handoff_assignee_id'].present?
    assignment
  end
end
