# RAEVO (08/10, 123jpnbcb4w): a lista do @ na resposta de um grupo de WhatsApp.
class Api::V1::Accounts::Conversations::WhatsappGroupParticipantsController < Api::V1::Accounts::Conversations::BaseController
  def index
    render json: { payload: WhatsappGroups::ParticipantsFromHistoryService.new(conversation: @conversation).perform }
  end
end
