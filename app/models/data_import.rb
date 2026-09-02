# == Schema Information
#
# Table name: data_imports
#
#  id                :bigint           not null, primary key
#  data_type         :string           not null
#  meta              :jsonb            not null
#  processed_records :integer
#  processing_errors :text
#  status            :integer          default("pending"), not null
#  total_records     :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#
# Indexes
#
#  index_data_imports_on_account_id  (account_id)
#
class DataImport < ApplicationRecord
  belongs_to :account
  DATA_TYPES = %w[contacts kanban_cards].freeze

  validates :data_type, inclusion: { in: DATA_TYPES, message: I18n.t('errors.data_import.data_type.invalid') }
  enum status: { pending: 0, processing: 1, completed: 2, failed: 3 }

  has_one_attached :import_file
  has_one_attached :failed_records

  after_create_commit :process_data_import

  private

  def process_data_import
    # we wait for the file to be uploaded to the cloud
    import_job.set(wait: 1.minute).perform_later(self)
  end

  # O job dos contactos diz na primeira linha que foi escrito só para eles.
  # Oportunidades têm o seu, em vez de o alargar até deixar de se perceber.
  def import_job
    data_type == 'kanban_cards' ? KanbanCards::ImportJob : DataImportJob
  end
end
