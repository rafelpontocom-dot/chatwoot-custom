# RAEVO (08/10, 123jpnbcb58): o feed de status do WhatsApp (`status@broadcast`) e
# as listas de transmissão (`<número>@broadcast`) entram pelo WAHA como contato,
# e não são pessoas. Nascem bloqueados — no Chatwoot é o mesmo que silenciar: a
# conversa nasce resolvida e mensagem nova não a reabre. A variável do WAHA que
# corta na origem não chegou às sessões que já existiam; isto não depende dela.
#
# Só ao gravar o identificador: quem desbloquear à mão não é bloqueado outra vez.
module WhatsappBroadcastContact
  extend ActiveSupport::Concern

  included do
    before_save :block_whatsapp_broadcast, if: :will_save_change_to_identifier?
  end

  private

  def block_whatsapp_broadcast
    self.blocked = true if identifier.to_s.downcase.end_with?('@broadcast')
  end
end
