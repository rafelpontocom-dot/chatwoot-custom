class Api::V1::Accounts::Contacts::KanbanCardsController < Api::V1::Accounts::BaseController
  before_action :fetch_contact
  before_action :authorize_contact

  def index
    @kanban_cards = linked_kanban_cards.select { |kanban_card| KanbanCardPolicy.new(user_context, kanban_card).show? }
    @labels_by_title = Current.account.labels.where(title: linked_label_titles).index_by(&:title)
  end

  private

  def fetch_contact
    @contact = Current.account.contacts.find(params[:contact_id])
  end

  def authorize_contact
    authorize @contact, :show?
  end

  def linked_kanban_cards
    KanbanCard.where(account_id: Current.account.id)
              .active
              .where(contact_id: @contact.id)
              .joins(:kanban_board, :kanban_stage)
              .merge(KanbanBoard.active)
              .merge(KanbanStage.active)
              .includes(:kanban_board, :kanban_stage, :contact, :inbox, :conversation, :labels)
              .order('kanban_boards.position ASC, kanban_stages.position ASC, kanban_cards.position ASC, kanban_cards.id ASC')
  end

  def linked_label_titles
    @kanban_cards.flat_map { |kanban_card| kanban_card.labels.map(&:name) }.uniq
  end

  def user_context
    { user: Current.user, account: Current.account, account_user: Current.account_user }
  end
end
