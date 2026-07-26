class Api::V1::Accounts::KanbanBoards::AutomationConnectionsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board
  before_action :fetch_connection, only: [:update, :destroy, :reset_secret]

  def index
    render json: @kanban_board.kanban_automation_connections.order(:name).map { |connection| connection_payload(connection) }
  end

  def create
    connection = @kanban_board.kanban_automation_connections.new(connection_params.merge(account: Current.account))
    connection.save!
    audit_connection(connection, 'created')
    render json: connection_payload(connection, include_secret: true), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def update
    @connection.update!(connection_params)
    audit_connection(@connection, 'updated', changed_fields: @connection.previous_changes.keys & %w[name webhook_url active])
    render json: connection_payload(@connection)
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def destroy
    audit_connection(@connection, 'deleted', connection_name: @connection.name)
    @connection.destroy!
    head :no_content
  end

  def reset_secret
    @connection.reset_secret!
    audit_connection(@connection, 'secret_reset')
    render json: connection_payload(@connection, include_secret: true)
  end

  def audits
    render json: @kanban_board.kanban_automation_connection_audits.order(created_at: :desc).limit(100).map { |audit| audit_payload(audit) }
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end

  def authorize_kanban_board
    authorize @kanban_board, :update?
  end

  def fetch_connection
    @connection = @kanban_board.kanban_automation_connections.find(params[:id])
  end

  def connection_params
    params.require(:automation_connection).permit(:name, :webhook_url, :active)
  end

  def connection_payload(connection, include_secret: false)
    {
      id: connection.id,
      name: connection.name,
      webhook_url: connection.webhook_url,
      inbound_webhook_url: inbound_webhook_url(connection),
      active: connection.active,
      secret_present: connection.secret.present?,
      created_at: connection.created_at.iso8601,
      updated_at: connection.updated_at.iso8601
    }.tap { |payload| payload[:secret] = connection.secret if include_secret }
  end

  def audit_connection(connection, action, metadata = {})
    @kanban_board.kanban_automation_connection_audits.create!(
      account: Current.account,
      kanban_automation_connection: connection,
      actor: Current.user,
      action: action,
      metadata: metadata
    )
  end

  def audit_payload(audit)
    {
      id: audit.id,
      connection_id: audit.kanban_automation_connection_id,
      action: audit.action,
      metadata: audit.metadata,
      actor_id: audit.actor_id,
      created_at: audit.created_at.iso8601
    }
  end

  def inbound_webhook_url(connection)
    "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/kanban/#{connection.inbound_token}"
  end
end
