class Api::V1::Accounts::Calendar::BookingPageController < Api::V1::Accounts::BaseController
  before_action :fetch_booking_page

  def show
    authorize @booking_page, :show?
    render json: booking_page_payload
  end

  def update
    authorize @booking_page, :configure?
    @booking_page.update!(booking_page_params)
    render json: booking_page_payload
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  private

  def fetch_booking_page
    @booking_page = Current.account.kanban_calendar_booking_page ||
                    Current.account.create_kanban_calendar_booking_page!
  end

  def booking_page_params
    params.require(:booking_page).permit(
      :active,
      :title,
      :description,
      :duplicate_policy,
      :minimum_notice_minutes,
      :maximum_notice_days,
      :slot_interval_minutes,
      :captcha_provider,
      :captcha_site_key,
      :kanban_board_id,
      :kanban_stage_id,
      :inbox_id,
      public_form_fields: [:key, :label, :kind, :required, { options: [] }]
    )
  end

  def booking_page_payload
    {
      active: @booking_page.active,
      public_token: @booking_page.public_token,
      title: @booking_page.title,
      description: @booking_page.description,
      duplicate_policy: @booking_page.duplicate_policy,
      minimum_notice_minutes: @booking_page.minimum_notice_minutes,
      maximum_notice_days: @booking_page.maximum_notice_days,
      slot_interval_minutes: @booking_page.slot_interval_minutes,
      captcha_provider: @booking_page.captcha_provider,
      captcha_site_key: @booking_page.captcha_site_key,
      public_form_fields: @booking_page.public_form_fields,
      kanban_board_id: @booking_page.kanban_board_id,
      kanban_stage_id: @booking_page.kanban_stage_id,
      inbox_id: @booking_page.inbox_id
    }
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
