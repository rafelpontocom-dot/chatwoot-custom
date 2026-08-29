class Forms::SchemaContentValidator
  BLOCK_TYPES = %w[heading rich_text image divider].freeze
  RICH_TEXT_NODE_TYPES = %w[doc paragraph heading bulletList orderedList listItem hardBreak text].freeze
  RICH_TEXT_MARK_TYPES = %w[bold italic strike code link].freeze
  KEY_PATTERN = /\A[a-z][a-z0-9_]*\z/

  def initialize(blocks:)
    @blocks = blocks
  end

  def valid?
    return true if blocks.blank?
    return false unless blocks.is_a?(Array)

    blocks.all? { |block| valid_block?(block) } && unique_block_ids?
  end

  private

  attr_reader :blocks

  def valid_block?(block)
    block = block.to_h
    valid_block_id?(block['id']) && valid_block_content?(block)
  end

  def valid_block_id?(value)
    value.to_s.match?(KEY_PATTERN)
  end

  def unique_block_ids?
    blocks.map { |block| block.to_h['id'].to_s }.uniq.length == blocks.length
  end

  def valid_block_content?(block)
    return valid_text?(block['content']) if block['type'] == 'heading'
    return valid_rich_text?(block['content']) if block['type'] == 'rich_text'
    return valid_image?(block) if block['type'] == 'image'

    block['type'] == 'divider'
  end

  def valid_image?(block)
    safe_image_url?(block['url']) && optional_short_text?(block['alt']) && optional_short_text?(block['caption'])
  end

  def valid_rich_text?(value)
    valid_text?(value) || valid_rich_text_node?(value, root: true)
  end

  def valid_rich_text_node?(node, root: false, depth: 0)
    return false if depth > 12 || !node.is_a?(Hash)
    return false unless valid_node_type?(node['type'], root: root)
    return false unless valid_marks?(node['marks'])
    return valid_text_node?(node) if node['type'] == 'text'
    return valid_break_node?(node) if node['type'] == 'hardBreak'

    valid_container_node?(node, depth: depth)
  end

  def valid_node_type?(node_type, root:)
    RICH_TEXT_NODE_TYPES.include?(node_type) && (!root || node_type == 'doc')
  end

  def valid_text_node?(node)
    valid_text?(node['text']) && node['content'].blank? && node['attrs'].blank?
  end

  def valid_break_node?(node)
    node['content'].blank? && node['attrs'].blank?
  end

  def valid_container_node?(node, depth:)
    valid_node_attributes?(node['type'], node['attrs']) && valid_children?(node['content'], depth: depth)
  end

  def valid_children?(children, depth:)
    children.is_a?(Array) && children.present? && children.all? do |child|
      valid_rich_text_node?(child, depth: depth + 1)
    end
  end

  def valid_node_attributes?(node_type, attributes)
    return attributes.blank? unless node_type == 'heading'

    attributes.is_a?(Hash) && attributes.keys == ['level'] && (1..4).cover?(attributes['level'].to_i)
  end

  def valid_marks?(marks)
    marks.blank? || (marks.is_a?(Array) && marks.all? do |mark|
      valid_mark?(mark)
    end)
  end

  def valid_mark?(mark)
    return false unless mark.is_a?(Hash) && RICH_TEXT_MARK_TYPES.include?(mark['type'])
    return valid_link_mark?(mark) if mark['type'] == 'link'

    mark.except('type').blank?
  end

  def valid_link_mark?(mark)
    attributes = mark['attrs']
    return false unless attributes.is_a?(Hash) && safe_http_url?(attributes['href'])

    attributes.except('href', 'target', 'rel', 'class').blank? &&
      [nil, '_blank'].include?(attributes['target']) &&
      [nil, '', 'noopener noreferrer'].include?(attributes['rel']) &&
      attributes['class'].blank?
  end

  def valid_text?(value)
    value.is_a?(String) && value.strip.present? && value.length <= 10_000
  end

  def optional_short_text?(value)
    value.blank? || (value.is_a?(String) && value.length <= 500)
  end

  def safe_image_url?(value)
    return active_storage_url?(value) if value.to_s.start_with?('/')

    uri = URI.parse(value.to_s)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def active_storage_url?(value)
    value.to_s.start_with?('/rails/active_storage/blobs/')
  end

  def safe_http_url?(value)
    uri = URI.parse(value.to_s)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end
end
