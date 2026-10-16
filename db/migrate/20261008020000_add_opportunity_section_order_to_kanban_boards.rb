class AddOpportunitySectionOrderToKanbanBoards < ActiveRecord::Migration[7.1]
  # A ordem das secções da ficha da oportunidade passa a ser do FUNIL, e muda-se
  # nas Configurações — decisão do Pedro em 07/10: «reordenar somente nas
  # configurações». Vazia é a ordem de origem; a ficha reconcilia o que estiver
  # gravado com as secções que o funil tem.
  def change
    add_column :kanban_boards, :opportunity_section_order, :jsonb, null: false, default: []
  end
end
