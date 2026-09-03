class Marketing::TouchpointsQuery
  DEFAULT_LIMIT = 25
  MAX_LIMIT = 100

  def initialize(account:, params: {})
    @account = account
    @params = params
  end

  def records
    scope = account.marketing_touchpoints.recent_first
    scope = scope.where(occurred_at: period) if period.present?
    scope = scope.where(source: params[:source]) if params[:source].present?
    scope = scope.where("payload ->> 'origem_do_lead' = ?", params[:origin]) if params[:origin].present?
    scope.includes(:contact, :kanban_card).limit(limit).offset(offset)
  end

  def total_count
    scope = account.marketing_touchpoints
    scope = scope.where(occurred_at: period) if period.present?
    scope.count
  end

  def limit
    @limit ||= (params[:limit] || DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)
  end

  def offset
    @offset ||= [params[:page].to_i - 1, 0].max * limit
  end

  private

  attr_reader :account, :params

  def period
    return if params[:since].blank? && params[:until].blank?

    since = parse_time(params[:since]) || 100.years.ago
    ending = parse_time(params[:until]) || Time.current

    since..ending
  end

  def parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
