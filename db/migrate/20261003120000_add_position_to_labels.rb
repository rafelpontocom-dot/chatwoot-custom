class AddPositionToLabels < ActiveRecord::Migration[7.1]
  def change
    add_column :labels, :position, :integer
  end
end
