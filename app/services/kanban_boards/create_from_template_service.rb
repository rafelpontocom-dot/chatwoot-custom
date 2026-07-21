class KanbanBoards::CreateFromTemplateService
  TEMPLATES = {
    'whatsapp_sales' => ['Novo lead', 'Em conversa', 'Interesse identificado', 'Proposta enviada', 'Follow-up', 'Fechado', 'Perdido'],
    'clinic' => ['Novo lead', 'Qualificado', 'Consulta agendada', 'Confirmado', 'Compareceu', 'Fechado', 'Perdido'],
    'b2b' => ['Novo lead', 'Diagnóstico', 'Proposta', 'Negociação', 'Contrato enviado', 'Fechado', 'Perdido'],
    'blank' => []
  }.freeze

  def initialize(account:, attributes:, template_key:)
    @account = account
    @attributes = attributes
    @template_key = template_key.presence || 'blank'
  end

  def perform!
    stage_names = TEMPLATES.fetch(template_key)

    KanbanBoard.transaction do
      board = KanbanBoard.create!(attributes.merge(account: account))
      stage_names.each.with_index(1) do |name, position|
        board.kanban_stages.create!(account: account, name: name, position: position)
      end
      board
    end
  end

  private

  attr_reader :account, :attributes, :template_key
end
