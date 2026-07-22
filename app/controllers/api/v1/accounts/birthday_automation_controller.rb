class Api::V1::Accounts::BirthdayAutomationController < Api::V1::Accounts::BaseController
  before_action :authorize_birthday_automation

  def show
    @automation = Current.account.kanban_birthday_automation || Current.account.build_kanban_birthday_automation
    render json: payload
  end

  def update
    @automation = Current.account.kanban_birthday_automation || Current.account.build_kanban_birthday_automation
    @automation.update!(birthday_automation_params)
    render json: payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  private

  def authorize_birthday_automation
    return if Current.account_user&.administrator?

    render json: { error: 'You are not authorized to manage birthday automation.' }, status: :forbidden
  end

  def birthday_automation_params
    params.require(:birthday_automation).permit(
      :active,
      :days_before,
      :opt_in_attribute_key,
      :message_locale,
      :timezone,
      :send_time,
      :message_template,
      delivery_channels: [],
      whatsapp_template_params: {}
    )
  end

  def payload
    {
      active: @automation.active,
      days_before: @automation.days_before,
      delivery_channels: @automation.delivery_channels,
      opt_in_attribute_key: @automation.opt_in_attribute_key,
      message_locale: @automation.message_locale,
      timezone: @automation.timezone,
      timezone_name: @automation.timezone_name,
      send_time: @automation.send_time,
      message_template: @automation.message_template,
      whatsapp_template_params: @automation.whatsapp_template_params
    }
  end
end
