class Marketing::AttributionFields
  # As chaves da aba Marketing da oportunidade, na ordem canonica do preset
  # (KanbanBoardSettings.vue). Gravar com estes nomes faz do carimbo no card um
  # `merge` e nao uma traducao — e uma chave fora desta lista e descartada em
  # silencio pelo proprio KanbanCard, o que torna o carimbo seguro.
  CARD_KEYS = %w[
    origem_do_lead
    sub_origem
    campaign
    adset
    ad
    utm_content
    utm_medium
    utm_campaign
    utm_source
    utm_term
    utm_referrer
    referrer
    gclientid
    gclid
    fbclid
    ttad_name
    ttad_id
    fbc
    fbp
    ttclid
    campaign_id
    adset_id
    ad_id
    landing_page
    event_id
    landing_page_full
  ].freeze

  # Guardadas no contato, fora do card.
  #
  # `gbraid` e `wbraid` sao os identificadores de clique do Google para
  # privacidade no iOS — em trafego de iPhone o Google manda estes *em vez de*
  # `gclid`. Capturar e barato e nao da para voltar no tempo; exibi-los espera a
  # fase do Google, quando ha o que fazer com eles.
  CONTACT_ONLY_KEYS = %w[gbraid wbraid msclkid dclid utm_id].freeze

  ALL_KEYS = (CARD_KEYS + CONTACT_ONLY_KEYS).freeze

  # Teto por valor: um cliente hostil nao enche o jsonb, e nenhuma URL honesta
  # carrega um utm_campaign de meio kilobyte.
  MAX_VALUE_LENGTH = 500

  class << self
    # Aceita qualquer hash e devolve so o que e atribuicao, limpo.
    def normalize(raw)
      return {} if raw.blank?

      raw.to_h.each_with_object({}) do |(key, value), memo|
        name = key.to_s.downcase.strip
        next unless ALL_KEYS.include?(name)

        cleaned = clean(value)
        memo[name] = cleaned if cleaned.present?
      end
    end

    # O subconjunto que a aba Marketing do card sabe mostrar.
    def card_values(attribution)
      attribution.to_h.slice(*CARD_KEYS)
    end

    private

    def clean(value)
      return nil if value.nil? || value.is_a?(Hash) || value.is_a?(Array)

      value.to_s.strip.truncate(MAX_VALUE_LENGTH)
    end
  end
end
