class Forms::ExpireInvitationsService
  BATCH_SIZE = 100

  def initialize(now: Time.current)
    @now = now
  end

  def perform!
    expired_invitations.find_each(batch_size: BATCH_SIZE) do |invitation|
      expire(invitation)
    end
  end

  private

  attr_reader :now

  def expired_invitations
    FormInvitation.where(status: 'active').where.not(expires_at: nil).where('expires_at < ?', now)
  end

  def expire(invitation)
    return unless invitation.expire_if_needed!(now: now)

    Forms::InvitationEventDispatcher.new(invitation: invitation).dispatch_expired(timestamp: now)
  end
end
