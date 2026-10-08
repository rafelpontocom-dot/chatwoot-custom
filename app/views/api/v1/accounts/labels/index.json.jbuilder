json.payload do
  json.array! @labels do |label|
    json.partial! 'api/v1/accounts/labels/label', label: label
  end
end
