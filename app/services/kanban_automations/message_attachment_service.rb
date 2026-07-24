class KanbanAutomations::MessageAttachmentService
  def initialize(data:)
    @data = data.to_h.with_indifferent_access
  end

  def signed_id
    return if attachment.blank?

    blob.signed_id if blob&.image?
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    nil
  end

  def valid?
    attachment.blank? || signed_id.present?
  end

  private

  attr_reader :data

  def attachment
    @attachment ||= data[:message_attachment].to_h.with_indifferent_access
  end

  def blob
    @blob ||= ActiveStorage::Blob.find_signed(attachment[:signed_id].to_s)
  end
end
