#!/usr/bin/env ruby
# Regista os textos que o Raevo mudou ou acrescentou nos ficheiros de tradução
# do Chatwoot, contra a tag oficial em `upstreamBase`. O teste
# spec/raevo/translation_overrides_spec.rb falha se algum deles voltar ao
# original — que é o que um upgrade ou uma sincronização do Crowdin fazem sem
# conflito.
#
# Mudou um texto de propósito? Corra outra vez e leia o diff do JSON:
#   ruby scripts/raevo-translation-overrides.rb
require 'json'
require 'yaml'
require 'open3'

ROOT = File.expand_path('..', __dir__)
CONTRACTS = JSON.parse(File.read(File.join(ROOT, 'config/raevo/upstream-contracts.json')))
BASE = CONTRACTS.fetch('upstreamBase')
OUTPUT = File.join(ROOT, 'config/raevo/translation-overrides.json')

def flatten(value, prefix = nil, out = {})
  case value
  when Hash then value.each { |key, child| flatten(child, [prefix, key].compact.join('.'), out) }
  else out[prefix] = value
  end
  out
end

def parse(path, content)
  path.end_with?('.json') ? JSON.parse(content) : YAML.safe_load(content, aliases: true)
end

def upstream_content(path)
  out, status = Open3.capture2('git', 'show', "#{BASE}:#{path}", chdir: ROOT)
  status.success? ? out : nil
end

files = CONTRACTS.fetch('contracts').find { |c| c['id'] == 'raevo-translations' }&.fetch('paths') ||
        abort('contrato raevo-translations em falta em upstream-contracts.json')

overrides = files.select { |path| path.end_with?('.json', '.yml') }.sort.to_h do |path|
  ours = flatten(parse(path, File.read(File.join(ROOT, path))))
  base_content = upstream_content(path)
  theirs = base_content ? flatten(parse(path, base_content)) : {}
  [path, ours.reject { |key, value| theirs.key?(key) && theirs[key] == value }.sort.to_h]
end

File.write(OUTPUT, "#{JSON.pretty_generate({ upstreamBase: BASE, files: overrides })}\n")
puts "#{overrides.sum { |_, keys| keys.size }} textos em #{overrides.size} ficheiros → #{OUTPUT.sub("#{ROOT}/", '')}"
