class Forms::DetectAbandonedInvitationsService
  BATCH_SIZE = 100

  def initialize(now: Time.current)
    @now = now
  end

  def perform!
    eligible_invitations.find_each(batch_size: BATCH_SIZE) do |invitation|
      detect_abandonment(invitation)
    end
  end

  private

  attr_reader :now

  def eligible_invitations
    FormInvitation.where(status: 'active', abandoned_at: nil, opened_at: nil, completed_at: nil)
                  .where.not(sent_at: nil)
                  .includes(form_template_version: :form_template)
  end

  def detect_abandonment(invitation)
    delay_hours = invitation.form_template_version.form_template.abandonment_delay_hours
    return if delay_hours.blank? || invitation.sent_at > now - delay_hours.hours
    return unless invitation.mark_abandoned!(now: now)

    Forms::InvitationEventDispatcher.new(invitation: invitation).dispatch_abandoned(timestamp: now)
  end
end
