class Api::V1::Accounts::Marketing::TouchpointsController < Api::V1::Accounts::BaseController
  before_action :ensure_marketing_module_enabled
  before_action :authorize_view

  def index
    query = Marketing::TouchpointsQuery.new(account: Current.account, params: params)
    render json: {
      payload: query.records.map { |touchpoint| touchpoint_payload(touchpoint) },
      meta: { total_count: query.total_count, limit: query.limit, offset: query.offset }
    }
  end

  def summary
    render json: Marketing::TouchpointsSummary.new(
      account: Current.account,
      since: parse_time(params[:since]),
      until_time: parse_time(params[:until])
    ).perform
  end

  private

  def ensure_marketing_module_enabled
    return if Current.account.marketing_module_setting&.enabled?

    render json: { message: 'Marketing module is not enabled for this account' }, status: :forbidden
  end

  def authorize_view
    authorize MarketingTouchpoint, :view?
  end

  def touchpoint_payload(touchpoint)
    {
      id: touchpoint.id,
      source: touchpoint.source,
      occurred_at: touchpoint.occurred_at,
      payload: touchpoint.payload,
      contact: touchpoint.contact && { id: touchpoint.contact.id, name: touchpoint.contact.name },
      kanban_card_id: touchpoint.kanban_card_id,
      conversation_id: touchpoint.conversation_id
    }
  end

  def parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
