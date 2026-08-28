class AddSensitiveAnswersToFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    add_column :form_submissions, :sensitive_answers_ciphertext, :text
  end
end
