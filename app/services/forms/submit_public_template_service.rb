class Forms::SubmitPublicTemplateService
  CONTACT_FIELDS = %w[name email phone_number].freeze

  def initialize(form_template:, answers:)
    @form_template = form_template
    @answers = answers.to_h.stringify_keys
  end

  def perform!
    validate_answers!

    submission = FormSubmission.transaction do
      submission = FormSubmission.new(
        account: form_template.account,
        form_template_version: form_template.active_version,
        contact: find_or_create_contact!,
        answers: permitted_answers,
        metadata: { 'source' => 'public_link' },
        submitted_at: Time.current
      )
      submission.save!
      submission
    end

    Forms::MapSubmissionToCrmService.new(submission: submission).perform
    Forms::CreatePublicOpportunityService.new(submission: submission).perform
    submission
  end

  private

  attr_reader :form_template

  def find_or_create_contact!
    existing_contact || form_template.account.contacts.create!(contact_attributes)
  end

  def existing_contact
    matches = [contact_by_email, contact_by_phone].compact.uniq
    invalid_submission!('E-mail e telefone pertencem a contatos diferentes') if matches.many?

    matches.first
  end

  def contact_by_email
    return if contact_attributes[:email].blank?

    form_template.account.contacts.from_email(contact_attributes[:email])
  end

  def contact_by_phone
    return if contact_attributes[:phone_number].blank?

    form_template.account.contacts.find_by(phone_number: contact_attributes[:phone_number])
  end

  def contact_attributes
    @contact_attributes ||= begin
      attributes = contact_mapping.slice(*CONTACT_FIELDS).filter_map do |attribute, answer_key|
        [attribute, answer_value(answer_key)] if answer_value(answer_key).present?
      end.to_h.symbolize_keys
      attributes[:phone_number] = normalized_phone_number(attributes[:phone_number]) if attributes[:phone_number]
      invalid_submission!('O formulário público precisa mapear nome e e-mail ou telefone') unless valid_contact_attributes?(attributes)
      attributes
    end
  end

  def valid_contact_attributes?(attributes)
    attributes[:name].present? && (attributes[:email].present? || attributes[:phone_number].present?)
  end

  def validate_answers!
    return if answers_validator.valid?

    invalid_submission!(answers_validator.errors.to_sentence)
  end

  def permitted_answers
    @permitted_answers ||= answers_validator.permitted_answers
  end

  def answers_validator
    @answers_validator ||= Forms::AnswersValidator.new(
      schema: form_template.active_version.schema,
      answers: @answers
    )
  end

  def contact_mapping
    form_template.active_version.schema.fetch('crm_mapping', {}).fetch('contact', {}).to_h
  end

  def answer_value(key)
    permitted_answers[key.to_s]
  end

  def normalized_phone_number(phone_number)
    Forms::PhoneNumberNormalizer.new(
      phone_number: phone_number,
      locale: form_template.settings['locale'].presence || form_template.account.locale
    ).call
  end

  def invalid_submission!(message)
    submission = FormSubmission.new
    submission.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, submission
  end
end
