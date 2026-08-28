class Api::V1::Accounts::Finance::PaymentsController < Api::V1::Accounts::BaseController
  before_action :ensure_finance_module_enabled

  def index
    authorize finance_module_setting, :view_payments?
    payments = filtered_payments
               .includes(:contact, :finance_provider_connection, kanban_card: :owner)
               .order(created_at: :desc)

    render json: payments.map(&:public_payload)
  end

  def summary
    authorize finance_module_setting, :view_payments?
    render json: Finance::PaymentsSummary.new(scope: filtered_payments).call
  end

  def show
    authorize finance_module_setting, :view_payments?
    payment = Current.account.finance_payments
                     .includes(:contact, :finance_provider_connection, :finance_payment_events)
                     .find(params[:id])
    events = payment.finance_payment_events.order(occurred_at: :desc).map(&:public_payload)

    render json: payment.public_payload.merge(events: events)
  end

  def create
    authorize finance_module_setting, :create_payments?
    payment = create_payment_service.perform

    render json: payment.public_payload, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  rescue Finance::Asaas::ApiError => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  def cancel
    authorize finance_module_setting, :manage_payments?
    payment = Current.account.finance_payments.find(params[:id])
    canceled_payment = payment_cancel_service_class(payment).new(
      payment: payment,
      actor: Current.user
    ).perform

    events = canceled_payment.finance_payment_events.order(occurred_at: :desc).map(&:public_payload)
    render json: canceled_payment.public_payload.merge(events: events)
  rescue Finance::Asaas::ApiError => e
    render json: { message: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def mark_received
    authorize finance_module_setting, :manage_payments?
    payment = Current.account.finance_payments.find(params[:id])
    received_payment = Finance::Manual::MarkPaymentReceivedService.new(
      payment: payment,
      actor: Current.user
    ).perform

    events = received_payment.finance_payment_events.order(occurred_at: :desc).map(&:public_payload)
    render json: received_payment.public_payload.merge(events: events)
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def refund
    authorize finance_module_setting, :refund_payments?
    payment = Current.account.finance_payments.find(params[:id])
    refunded_payment = Finance::Asaas::RefundPaymentService.new(
      payment: payment,
      actor: Current.user,
      description: refund_params[:description]
    ).perform

    events = refunded_payment.finance_payment_events.order(occurred_at: :desc).map(&:public_payload)
    render json: refunded_payment.public_payload.merge(events: events)
  rescue Finance::Asaas::ApiError => e
    render json: { message: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def ensure_finance_module_enabled
    return if finance_module_setting.enabled?

    render json: { message: 'Finance module is not enabled for this account' }, status: :forbidden
  end

  def finance_module_setting
    @finance_module_setting ||= Current.account.finance_module_setting || Current.account.build_finance_module_setting
  end

  def payment_connection
    @payment_connection ||= Current.account.finance_provider_connections.find(create_payment_params[:finance_provider_connection_id])
  end

  def payment_contact
    @payment_contact ||= Current.account.contacts.find(create_payment_params[:contact_id])
  end

  def payment_card
    return if create_payment_params[:kanban_card_id].blank?

    Current.account.kanban_cards.find(create_payment_params[:kanban_card_id])
  end

  def create_payment_params
    params.require(:payment).permit(
      :contact_id,
      :finance_provider_connection_id,
      :kanban_card_id,
      :amount_cents,
      :billing_type,
      :due_on,
      :currency,
      :cpf_cnpj,
      :description
    )
  end

  def payment_service_class
    {
      'asaas' => Finance::Asaas::CreatePaymentService,
      'manual' => Finance::Manual::CreatePaymentService
    }.fetch(payment_connection.provider)
  end

  def create_payment_service
    payment_service_class.new(payment_service_arguments)
  end

  def payment_service_arguments
    {
      connection: payment_connection,
      contact: payment_contact,
      kanban_card: payment_card,
      actor: Current.user,
      **payment_attributes
    }
  end

  def payment_attributes
    create_payment_params.to_h.symbolize_keys
                         .except(:contact_id, :finance_provider_connection_id, :kanban_card_id)
                         .merge(currency: requested_currency)
  end

  def requested_currency
    create_payment_params[:currency].presence || default_currency
  end

  def payment_cancel_service_class(payment)
    {
      'asaas' => Finance::Asaas::CancelPaymentService,
      'manual' => Finance::Manual::CancelPaymentService
    }.fetch(payment.finance_provider_connection.provider)
  end

  def default_currency
    payment_connection.provider == 'manual' && finance_module_setting.market == 'PT' ? 'EUR' : 'BRL'
  end

  def payment_filters
    params.permit(:status, :due_from, :due_to, :owner_id, :query).to_h.symbolize_keys
  end

  def refund_params
    params.fetch(:refund, {}).permit(:description)
  end

  def filtered_payments
    payments = Current.account.finance_payments
    payments = payments.where(kanban_card_id: params[:kanban_card_id]) if params[:kanban_card_id].present?

    Finance::PaymentsQuery.new(scope: payments, filters: payment_filters).call
  end
end
