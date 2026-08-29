class Forms::PhoneNumberNormalizer
  E164_PATTERN = /\A\+[1-9]\d{1,14}\z/
  COUNTRY_FORMATS = {
    'pt_BR' => { calling_code: '55', national_lengths: [10, 11] },
    'pt-BR' => { calling_code: '55', national_lengths: [10, 11] },
    'pt_PT' => { calling_code: '351', national_lengths: [9] },
    'pt-PT' => { calling_code: '351', national_lengths: [9] }
  }.freeze

  def initialize(phone_number:, locale:)
    @phone_number = phone_number.to_s.strip
    @locale = locale.to_s
  end

  def call
    return phone_number if phone_number.match?(E164_PATTERN)

    format = COUNTRY_FORMATS[locale]
    return phone_number unless format

    digits = phone_number.gsub(/\D/, '')
    return phone_number if digits.blank?
    return "+#{digits}" if valid_international_digits?(digits, format)
    return "+#{format[:calling_code]}#{digits}" if format[:national_lengths].include?(digits.length)

    phone_number
  end

  private

  attr_reader :phone_number, :locale

  def valid_international_digits?(digits, format)
    digits.start_with?(format[:calling_code]) &&
      format[:national_lengths].include?(digits.delete_prefix(format[:calling_code]).length)
  end
end
