class LlmFormatter::ContactLlmFormatter < LlmFormatter::DefaultLlmFormatter
  def format(*)
    sections = []
    sections << "Contact ID: ##{@record.id}"
    sections << 'Contact Attributes:'
    sections << build_attributes
    sections << 'Contact Notes:'
    sections << if @record.notes.any?
                  build_notes
                else
                  'No notes for this contact'
                end

    sections.join("\n")
  end

  private

  def build_notes
    @record.notes.all.map { |note| " - #{note.content}" }.join("\n")
  end

  def build_attributes
    attributes = []
    attributes << "Name: #{@record.name}"
    attributes << "Email: #{@record.email}"
    attributes << "Phone: #{@record.phone_number}"
    attributes << "Location: #{@record.location}"
    attributes << "Country Code: #{@record.country_code}"
    # Ordem explícita: o mesmo contacto tem de dar o mesmo prompt, e uma consulta sem
    # `order` devolve a ordem física das linhas, que muda com o uso da tabela.
    @record.account.custom_attribute_definitions.with_attribute_model('contact_attribute').order(:id).each do |attribute|
      attributes << "#{attribute.attribute_display_name}: #{@record.custom_attributes[attribute.attribute_key]}"
    end
    attributes.join("\n")
  end
end
