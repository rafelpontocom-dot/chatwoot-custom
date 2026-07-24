# == Schema Information
#
# Table name: kanban_birthday_automations
#
#  id                       :bigint           not null, primary key
#  active                   :boolean          default(FALSE), not null
#  days_before              :integer          default(0), not null
#  delivery_channels        :string           default([]), not null, is an Array
#  message_template         :text             default("Feliz aniversário, {{contact_name}}! Desejamos um dia especial para você."), not null
#  message_locale           :string           default("pt_BR"), not null
#  message_attachment       :jsonb            not null
#  opt_in_attribute_key     :string           default("birthday_messages_opt_in"), not null
#  send_time                :string           default("09:00"), not null
#  timezone                 :string
#  whatsapp_template_params :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#
# Indexes
#
#  index_kanban_birthday_automations_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class KanbanBirthdayAutomation < ApplicationRecord
  CHANNELS = %w[whatsapp email].freeze
  DEFAULT_OPT_IN_ATTRIBUTE_KEY = 'birthday_messages_opt_in'.freeze
  DEFAULT_SEND_TIME = '09:00'.freeze
  DEFAULT_MESSAGE_TEMPLATE = 'Feliz aniversário, {{contact_name}}! Desejamos um dia especial para você.'.freeze
  MESSAGE_LOCALES = %w[pt_BR pt_PT].freeze

  belongs_to :account
  has_many :kanban_birthday_deliveries, dependent: :destroy

  before_validation :normalize_configuration

  validates :account_id, uniqueness: true
  validates :days_before, numericality: { only_integer: true, in: 0..30 }
  validate :delivery_channels_are_supported
  validates :opt_in_attribute_key, format: { with: /\A[a-z][a-z0-9_]*\z/ }, allow_blank: false
  validates :message_template, presence: true, length: { maximum: 4_000 }
  validate :message_attachment_must_be_valid
  validates :message_locale, inclusion: { in: MESSAGE_LOCALES }
  validates :send_time, format: { with: /\A(?:[01]\d|2[0-3]):[0-5]\d\z/ }
  validate :timezone_must_exist

  def timezone_name
    timezone.presence || account.reporting_timezone.presence || Time.zone.name
  end

  def active_channel?(channel)
    active? && delivery_channels.include?(channel.to_s)
  end

  private

  def normalize_configuration
    self.delivery_channels = Array(delivery_channels).map(&:to_s).uniq
    self.opt_in_attribute_key = opt_in_attribute_key.to_s.strip.presence || DEFAULT_OPT_IN_ATTRIBUTE_KEY
    self.send_time = send_time.to_s.strip.presence || DEFAULT_SEND_TIME
    self.message_template = message_template.to_s.strip.presence || DEFAULT_MESSAGE_TEMPLATE
    normalize_message_locale
    normalize_message_configuration
  end

  def normalize_message_configuration
    self.whatsapp_template_params = whatsapp_template_params.to_h
    self.message_attachment = message_attachment.to_h
  end

  def normalize_message_locale
    self.message_locale = MESSAGE_LOCALES.include?(message_locale.to_s) ? message_locale.to_s : 'pt_BR'
  end

  def timezone_must_exist
    errors.add(:timezone, 'is invalid') if timezone.present? && ActiveSupport::TimeZone[timezone].blank?
  end

  def delivery_channels_are_supported
    unsupported = Array(delivery_channels) - CHANNELS
    errors.add(:delivery_channels, "contains unsupported channels: #{unsupported.join(', ')}") if unsupported.present?
  end

  def message_attachment_must_be_valid
    return if KanbanAutomations::MessageAttachmentService.new(data: { message_attachment: message_attachment }).valid?

    errors.add(:message_attachment, 'must be a valid image upload')
  end
end
