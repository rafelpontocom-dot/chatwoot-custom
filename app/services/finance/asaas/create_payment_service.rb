class Finance::Asaas::CreatePaymentService
  def initialize(connection:, contact:, **attributes)
    @connection = connection
    @contact = contact
    @amount_cents = attributes.fetch(:amount_cents)
    @billing_type = attributes.fetch(:billing_type)
    @due_on = attributes.fetch(:due_on)
    @cpf_cnpj = attributes.fetch(:cpf_cnpj)
    @description = attributes[:description]
    @kanban_card = attributes[:kanban_card]
    @actor = attributes[:actor]
  end

  def perform
    ensure_connection_ready!
    payment = create_payment_record
    customer = find_or_create_customer
    response = create_or_reconcile_payment(payment, customer)

    persist_provider_payment(payment, customer, response)
    Finance::PaymentCreatedEventService.new(payment: payment, source: 'asaas_create', actor: @actor).perform

    payment
  rescue Finance::Asaas::ApiError
    payment.destroy! if payment&.persisted?
    raise
  end

  private

  def ensure_connection_ready!
    return if @connection.provider == 'asaas' && @connection.status == 'connected'

    raise Finance::Asaas::ApiError, 'The Asaas connection must be validated before creating charges'
  end

  def create_payment_record
    FinancePayment.create!(
      account: @connection.account,
      contact: @contact,
      kanban_card: @kanban_card,
      finance_provider_connection: @connection,
      amount_cents: @amount_cents,
      billing_type: @billing_type,
      due_on: @due_on,
      description: @description
    )
  end

  def find_or_create_customer
    @connection.with_lock do
      @connection.finance_customers.find_by(contact: @contact) || create_customer
    end
  end

  def create_or_reconcile_payment(payment, customer)
    client.create_payment(customer_id: customer.provider_customer_id, payload: payment_payload(payment))
  rescue Finance::Asaas::RequestUncertainError
    reconciled_payment = client.find_payment_by_external_reference(payment.external_reference)
    return reconciled_payment if reconciled_payment.present?

    raise Finance::Asaas::ApiError, 'Asaas payment could not be confirmed'
  end

  def persist_provider_payment(payment, customer, response)
    payment.update!(
      finance_customer: customer,
      provider_customer_id: customer.provider_customer_id,
      provider_payment_id: response.fetch('id'),
      status: payment_status(response.fetch('status')),
      invoice_url: response['invoiceUrl'],
      provider_payload: response
    )
  end

  def create_customer
    response = client.create_customer(
      name: @contact.name,
      cpf_cnpj: @cpf_cnpj,
      email: @contact.email,
      mobile_phone: @contact.phone_number,
      external_reference: "contact-#{@contact.id}"
    )
    @connection.finance_customers.create!(
      account: @connection.account,
      contact: @contact,
      provider_customer_id: response.fetch('id'),
      provider_payload: response,
      last_synced_at: Time.current
    )
  end

  def client
    @client ||= Finance::Asaas::Client.new(connection: @connection)
  end

  def payment_payload(payment)
    {
      billing_type: payment.billing_type.upcase,
      value: payment.amount_cents / 100.0,
      due_date: payment.due_on,
      description: payment.description,
      external_reference: payment.external_reference
    }
  end

  def payment_status(provider_status)
    provider_status.to_s.downcase.then { |status| FinancePayment::STATUSES.include?(status) ? status : 'pending' }
  end
end
