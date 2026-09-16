# O que a página pública de agendamento recebe: quem a clínica é, os
# procedimentos, e — por procedimento — profissionais, perguntas e cobrança.
class KanbanCalendar::PublicPagePayload
  def initialize(booking_page:)
    @booking_page = booking_page
  end

  def page(procedures:)
    {
      title: @booking_page.title.presence || account.name,
      description: @booking_page.description,
      locale: account.locale,
      clinic: clinic,
      public_form_fields: @booking_page.public_form_fields,
      captcha_site_key: @booking_page.captcha_site_key,
      procedures: procedures.map { |procedure| procedure_summary(procedure) }
    }
  end

  def procedure_summary(procedure)
    {
      slug: procedure.public_slug,
      title: procedure.public_title.presence || procedure.name,
      description: procedure.public_description,
      duration_minutes: procedure.duration_minutes,
      location_type: procedure.location_type,
      color: procedure.color,
      recurrence_allowed: procedure.recurrence_allowed,
      max_sessions: procedure.max_sessions,
      price_cents: (procedure.price_cents if procedure.payment_enabled?)
    }
  end

  def procedure_detail(procedure, resources:)
    availability = KanbanCalendar::ProcedureAvailability.new(procedure: procedure, patient: true)
    procedure_summary(procedure).merge(
      resources: resources.map { |resource| { id: resource.id, name: resource.name } },
      professionals: professionals(procedure, availability),
      timezone: availability.timezone,
      questions: questions(procedure),
      payment: payment(procedure),
      reschedule_allowed: procedure.reschedule_allowed
    )
  end

  def clinic
    name = @booking_page.clinic_name.presence || account.name
    {
      name: name,
      initials: name.split.reject { |word| word.length < 3 }.first(2).pluck(0).join.upcase.presence || name[0, 2].upcase,
      address: @booking_page.clinic_address,
      whatsapp: @booking_page.clinic_whatsapp
    }
  end

  private

  def account
    @booking_page.account
  end

  # Só aparece o seletor quando o paciente escolhe e há mais de um.
  def professionals(procedure, availability)
    return [] unless procedure.assignment_strategy == 'patient_choice'

    availability.professionals.map { |resource| { id: resource.id, name: resource.name } }
  end

  # `required: "feegow"` vira sim ou não aqui: o paciente não precisa de saber
  # porquê. Cobrança online também exige CPF — o provedor pede.
  def questions(procedure)
    cpf_needed = cpf_needed?(procedure)
    procedure.booking_questions.filter_map do |question|
      conditional = question['required'] == 'feegow'
      next if conditional && !cpf_needed

      question.slice('key', 'label', 'kind', 'options').merge('required' => conditional || question['required'])
    end
  end

  def cpf_needed?(procedure)
    procedure.mirrors_feegow? ||
      (procedure.payment_enabled? && KanbanCalendar::BookingPaymentService.offered_methods(procedure).intersect?(%w[pix card]))
  end

  def payment(procedure)
    methods = procedure.payment_enabled? ? KanbanCalendar::BookingPaymentService.offered_methods(procedure) : []
    return { enabled: false } if methods.empty?

    {
      enabled: true,
      mode: procedure.payment_mode,
      price_cents: procedure.price_cents,
      charge_cents: procedure.payment_mode == 'deposit' ? procedure.deposit_cents : procedure.price_cents,
      methods: methods,
      hold_minutes: procedure.hold_minutes,
      currency: 'BRL'
    }
  end
end
