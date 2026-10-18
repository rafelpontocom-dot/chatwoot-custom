# O Início editável (18/10): o layout que um administrador grava para a equipa.
#
# O de cada pessoa vive em `users.ui_settings`, como o resto das preferências de
# ecrã, e não passa por aqui. Este é o padrão da conta — o Início de quem nunca
# arrumou o seu — e vive em `accounts.internal_attributes`, que não é servido ao
# painel com as definições da conta nem cabe no esquema de `settings`.
#
# Aceita só a forma que o painel envia. Os ids e os mínimos espelham
# `raevoHomeLayout.js`; um bloco desconhecido ou fora da grelha é pedido mal
# feito, e devolve 422 em vez de ficar gravado a partir o Início de todos.
class Raevo::HomeLayout
  KEY = 'raevo_home_layout'.freeze
  VERSION = 1
  COLUMNS = 12
  MAX_ROW = 200
  MAX_TITLE = 60
  MIN_SIZE = { kpi: [2, 2], list: [4, 3] }.freeze
  WIDGETS = {
    'kpi-conversations' => :kpi, 'kpi-actions' => :kpi, 'kpi-agenda' => :kpi, 'kpi-payments' => :kpi,
    'today-appointments' => :list, 'open-conversations' => :list, 'overdue-actions' => :list,
    'overdue-payments' => :list, 'stale-opportunities' => :list
  }.freeze

  class Invalid < StandardError; end

  def self.for(account)
    account.internal_attributes[KEY]
  end

  def self.save!(account, raw)
    layout = normalize(raw)
    account.update!(internal_attributes: account.internal_attributes.merge(KEY => layout))
    layout
  end

  def self.normalize(raw)
    raise Invalid unless raw.is_a?(Hash) && raw['version'] == VERSION && raw['items'].is_a?(Array)

    items = raw['items'].map { |item| normalize_item(item) }
    raise Invalid unless items.pluck('id').uniq.size == items.size

    { 'version' => VERSION, 'items' => items }
  end

  def self.normalize_item(item)
    kind = item.is_a?(Hash) && WIDGETS[item['id']]
    raise Invalid unless kind

    box = item.slice('x', 'y', 'w', 'h')
    raise Invalid unless box.size == 4 && box.values.all?(Integer) && valid_box?(kind, box)
    raise Invalid unless valid_title?(item['title'])

    { 'id' => item['id'], **box, 'title' => item['title'].presence }.compact
  end

  def self.valid_title?(title)
    title.nil? || (title.is_a?(String) && title.length <= MAX_TITLE)
  end

  def self.valid_box?(kind, box)
    min_width, min_height = MIN_SIZE[kind]
    box['w'].between?(min_width, COLUMNS) && box['h'].between?(min_height, MAX_ROW) &&
      box['x'].between?(0, COLUMNS - box['w']) && box['y'].between?(0, MAX_ROW)
  end

  private_class_method :normalize_item, :valid_title?, :valid_box?
end
