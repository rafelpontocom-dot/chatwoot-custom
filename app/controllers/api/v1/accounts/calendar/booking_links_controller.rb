class Api::V1::Accounts::Calendar::BookingLinksController < Api::V1::Accounts::BaseController
  before_action :fetch_booking_page

  def index
    authorize @booking_page, :configure?
    render json: @booking_page.kanban_calendar_booking_links.order(created_at: :desc).map { |link| link_payload(link) }
  end

  def create
    authorize @booking_page, :configure?
    link = @booking_page.kanban_calendar_booking_links.new(link_params.merge(account: Current.account))
    link.save!
    render json: link_payload(link), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def fetch_booking_page
    @booking_page = Current.account.kanban_calendar_booking_page || Current.account.create_kanban_calendar_booking_page!
  end

  def link_params
    params.require(:booking_link).permit(:kanban_calendar_procedure_id, :expires_at, :max_uses)
  end

  def link_payload(link)
    {
      id: link.id,
      token: link.token,
      procedure_id: link.kanban_calendar_procedure_id,
      expires_at: link.expires_at,
      max_uses: link.max_uses,
      uses_count: link.uses_count,
      active: link.active
    }
  end
end
