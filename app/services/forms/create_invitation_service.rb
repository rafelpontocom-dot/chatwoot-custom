class Forms::CreateInvitationService
  Result = Struct.new(:invitation, :token, keyword_init: true)

  def initialize(account:, form_template_version:, **attributes)
    @account = account
    @form_template_version = form_template_version
    @contact = attributes[:contact]
    @kanban_card = attributes[:kanban_card]
    @expires_at = attributes[:expires_at]
    @max_uses = attributes.fetch(:max_uses, 1)
  end

  def perform
    token = SecureRandom.urlsafe_base64(32)
    invitation = FormInvitation.create!(
      account: @account,
      form_template_version: @form_template_version,
      contact: @contact,
      kanban_card: @kanban_card,
      expires_at: @expires_at,
      max_uses: @max_uses,
      token_digest: FormInvitation.digest_token(token)
    )

    Result.new(invitation: invitation, token: token)
  end
end
