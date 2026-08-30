require 'rails_helper'

describe ApplicationHelper do
  describe '#available_locales_with_name' do
    it 'offers only Portuguese, Brazil first' do
      codes = helper.available_locales_with_name.map { |lang| lang[:iso_639_1_code] }

      expect(codes).to eq(%w[pt_BR pt])
    end

    it 'never offers English in the picker' do
      codes = helper.available_locales_with_name.map { |lang| lang[:iso_639_1_code] }

      expect(codes).not_to include('en')
    end

    it 'keeps English registered for Rails fallbacks' do
      # config.i18n.fallbacks = [I18n.default_locale]; sem :en o Rails levanta
      # I18n::InvalidLocale ao cair no fallback.
      expect(Rails.configuration.i18n.available_locales).to include(:en)
    end
  end
end
