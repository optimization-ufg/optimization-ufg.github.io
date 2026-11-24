# Mantém _data/publications.yml em dia usando o OpenAlex:
#  1. procura, pelo ORCID de cada professor, artigos de revista que ainda não estão no arquivo
#     e os acrescenta ao fim, no formato do site;
#  2. completa volume, número e páginas dos artigos marcados "to appear" que já saíram num número
#     da revista (só os que ainda não têm volume).
#
# Critério para artigos novos: com DOI, publicados numa revista, a partir do ano de entrada do
# professor na UFG (campo "since" em _data/members.yml). DOIs listados em
# _data/publications-ignore.yml nunca são acrescentados.
#
# Uso: ruby scripts/atualiza-publicacoes.rb [--dry-run]
# Roda toda semana pelo GitHub Actions (.github/workflows/atualiza-publicacoes.yml), que publica
# o resultado e abre um aviso (issue) com a lista do que mudou.
require 'net/http'
require 'json'
require 'yaml'
require 'date'
require 'cgi'
require 'uri'

ROOT = File.expand_path('..', __dir__)
PUBS = File.join(ROOT, '_data', 'publications.yml')
AVISO = File.join(ROOT, 'aviso.md')
REPO = ENV['GITHUB_REPOSITORY'] || 'optimization-ufg/optimization-ufg.github.io'
DRY = ARGV.include?('--dry-run')
ORDER = %w[year status authors title journal volume issue pages doi url].freeze

def yload_text(s)
  YAML.safe_load(s, permitted_classes: [Date])
end

def yload(path)
  return nil unless File.exist?(path)
  yload_text(File.read(path, encoding: 'UTF-8'))
end

def get_json(url)
  uri = URI(url)
  3.times do |i|
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 60) do |h|
      h.get(uri.request_uri, 'User-Agent' => 'optimization-ufg-site (GitHub Actions)', 'Accept' => 'application/json')
    end
    return JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)
    warn "HTTP #{res.code} em #{url}"
    sleep(2 * (i + 1))
  end
  raise "falha ao consultar #{url}"
end

def norm_title(t)
  t.to_s.downcase.unicode_normalize(:nfd).gsub(/[^a-z0-9]/, '')
end

def clean(s)
  CGI.unescapeHTML(s.to_s.gsub(/<[^>]+>/, '')).tr("‐‑", '--').gsub(/\s+/, ' ').strip
end

def doi_of(w)
  w['doi'].to_s.sub(%r{\Ahttps?://(dx\.)?doi\.org/}i, '').downcase.strip
end

def pages_of(b)
  p = [b['first_page'], b['last_page']].compact.map(&:to_s).reject(&:empty?).uniq.join('–')
  p.empty? ? nil : p
end

def q(v)
  s = v.to_s
  needs = s.empty? || s =~ /\A[\s\-?:,\[\]{}#&*!|>'"%@`]/ || s.include?(': ') || s.include?(' #') ||
          s.end_with?(':') || s =~ /\A[\d.]+\z/ || s =~ /\A(true|false|yes|no|null|on|off|~)\z/i
  needs ? s.to_json : s
end

# Uma entrada do arquivo, na ordem de campos usada no site.
def emit(h)
  keys = ORDER + (h.keys - ORDER)
  out = +''
  keys.each do |k|
    v = h[k]
    next if v.nil? || v.to_s.empty? || k.start_with?('_')
    v = if %w[volume issue pages].include?(k) then v.to_s.to_json
        elsif k == 'year' then v
        else q(v)
        end
    out << (out.empty? ? '- ' : '  ') << "#{k}: #{v}\n"
  end
  out
end

# ---------- dados atuais ----------
members = yload(File.join(ROOT, '_data', 'members.yml'))
pubs = yload(PUBS) || []
ignore = (yload(File.join(ROOT, '_data', 'publications-ignore.yml')) || []).map { |x| (x.is_a?(Hash) ? x['doi'] : x).to_s.downcase.strip }

have_doi = pubs.map { |p| p['doi'].to_s.downcase.strip }.reject(&:empty?)
have_title = pubs.map { |p| norm_title(p['title']) }
journals = pubs.map { |p| p['journal'].to_s }.uniq

people = (members['faculty'] || []) + (members['former_faculty'] || [])
by_orcid = {}
people.each { |m| by_orcid[m['orcid'].to_s] = m if m['orcid'] }

# Palavras que aparecem com maiúscula no meio dos títulos já cadastrados (nomes próprios).
KEEP = %w[Riemannian Riemann Newton Hadamard Lipschitz Pareto Euclidean Banach Hilbert Lagrangian Lagrange
          Hessian Jacobian Kurdyka Łojasiewicz Polyak Gauss Armijo Wolfe Nesterov Bregman Fejér Moreau Yosida
          Douglas Rachford Frank Halpern Cauchy Barzilai Borwein Levenberg Marquardt Kantorovich Smale Lorentz
          Minkowski Brazil Brazilian Goiás Hölder Karush Kuhn Tucker Fenchel Legendre Chebyshev Krylov
          Steffensen Tikhonov Mann Krasnoselskii Picard Lyapunov Hestenes Stiefel Fletcher Reeves Polak
          Ribière Dai Yuan Shamanskii Fischer Burmeister Stackelberg Nash Bellman Markov Monte Carlo
          Weiszfeld Fermat Torricelli Huber Dinkelbach]
pubs.each do |p|
  p['title'].to_s.split(/\s+/).each_with_index do |w, i|
    next if i.zero?
    w.scan(/[[:alpha:]]+/).each { |part| KEEP << part if part =~ /\A[[:upper:]][[:lower:]]+\z/ }
  end
end
KEEP.uniq!

def sentence_case(title)
  t = title
  t = t.downcase if t == t.upcase # títulos inteiros em maiúsculas
  first = true
  after_colon = false
  t.split(/(\s+)/).map do |w|
    next w if w =~ /\A\s*\z/
    out = if first || after_colon
            w.sub(/[[:alpha:]]/) { |c| c.upcase }
          else
            w.gsub(/[[:alpha:]]+/) do |p|
              if KEEP.include?(p) || p =~ /[[:upper:]].*[[:upper:]]/ || (p.size == 1 && p != 'A') then p
              else p.downcase
              end
            end
          end
    first = false
    after_colon = w.end_with?(':', '?', '.')
    out
  end.join
end

PARTICLES = %w[de da do dos das del della di van von der le la du e y].freeze
SUFFIXES = %w[júnior junior jr jr. filho neto sobrinho].freeze

def cite_name(name)
  t = clean(name).split(/\s+/)
  return t.join(' ') if t.size < 2
  sur = [t.pop]
  sur.unshift(t.pop) if SUFFIXES.include?(sur[0].downcase) && t.size > 1
  ini = t.reject { |w| PARTICLES.include?(w.downcase) }
         .map { |w| w.split('-').map { |p| p.sub(/\.\z/, '')[0].to_s.upcase + '.' }.join('-') }
  "#{sur.join(' ')}, #{ini.join(' ')}"
end

def journal_name(name, known)
  key = ->(s) { s.downcase.gsub('&', 'and').gsub(/[^a-z]/, '') }
  known.find { |j| key.(j) == key.(name) } || name
end

# ---------- 1. artigos novos ----------
FIELDS = 'id,doi,title,publication_year,type,primary_location,locations,authorships,biblio'
found = {}

(members['faculty'] || []).each do |m|
  next unless m['orcid'] && m['since']
  cursor = '*'
  n = 0
  while cursor
    url = 'https://api.openalex.org/works?filter=' +
          URI.encode_www_form_component("author.orcid:#{m['orcid']},from_publication_date:#{m['since']}-01-01,type:article") +
          "&select=#{FIELDS}&per-page=200&cursor=#{URI.encode_www_form_component(cursor)}"
    data = get_json(url)
    (data['results'] || []).each do |w|
      n += 1
      doi = doi_of(w)
      next if doi.empty? || doi.start_with?('10.48550/', '10.2139/', '10.5281/') # arXiv, SSRN, Zenodo
      next if have_doi.include?(doi) || ignore.include?(doi)
      loc = ([w['primary_location']] + (w['locations'] || [])).compact.find { |l| l.dig('source', 'type') == 'journal' }
      next unless loc
      title = clean(w['title'])
      next if title.empty? || title =~ /\A(correction|erratum|corrigendum|retraction|reply|comment|preface|editorial|foreword|introduction to the special issue)\b/i
      next if have_title.include?(norm_title(title))
      next if w['publication_year'].to_i < m['since'].to_i
      e = (found[doi] ||= { 'w' => w, 'loc' => loc, 'title' => title, 'members' => [] })
      e['members'] << m unless e['members'].include?(m)
    end
    cursor = data.dig('meta', 'next_cursor')
    cursor = nil if (data['results'] || []).empty?
    sleep 0.2
  end
  warn "#{m['name']}: #{n} artigos no OpenAlex desde #{m['since']}"
end

new_entries = found.map do |doi, e|
  w = e['w']
  b = w['biblio'] || {}
  authors = (w['authorships'] || []).map do |a|
    orcid = a.dig('author', 'orcid').to_s.sub(%r{\Ahttps?://orcid\.org/}, '')
    (by_orcid[orcid] && by_orcid[orcid]['cite']) || cite_name(a.dig('author', 'display_name') || a['raw_author_name'])
  end
  {
    'year' => w['publication_year'],
    'status' => (b['volume'].to_s.empty? ? 'to appear' : nil),
    'authors' => authors.join('; '),
    'title' => sentence_case(e['title']),
    'journal' => journal_name(clean(e['loc'].dig('source', 'display_name')), journals),
    'volume' => b['volume'], 'issue' => b['issue'], 'pages' => pages_of(b),
    'doi' => doi,
    '_members' => e['members'].map { |m| m['name'] },
    '_github' => e['members'].map { |m| m['github'] }.compact
  }
end.sort_by { |x| [-x['year'].to_i, x['authors']] }

# ---------- 2. "to appear" que já saíram ----------
pending = pubs.select { |p| p['status'] == 'to appear' && p['volume'].to_s.empty? && !p['doi'].to_s.empty? }
published = {}
pending.map { |p| p['doi'].to_s.downcase.strip }.each_slice(40) do |dois|
  url = 'https://api.openalex.org/works?filter=' + URI.encode_www_form_component("doi:#{dois.join('|')}") +
        '&select=doi,publication_year,biblio&per-page=50'
  (get_json(url)['results'] || []).each do |w|
    b = w['biblio'] || {}
    published[doi_of(w)] = w unless b['volume'].to_s.empty?
  end
end

# ---------- grava ----------
txt = File.read(PUBS, encoding: 'UTF-8')
updated = []
unless published.empty?
  head, *blocks = txt.split(/^(?=- )/)
  blocks.map! do |blk|
    body, trail = blk.match(/\A(.*?\n)((?:[ \t]*(?:#.*)?\n)*)\z/m)&.captures || [blk, '']
    h = (yload_text(body) || [])[0]
    w = h && published[h['doi'].to_s.downcase.strip]
    next blk unless w && h['status'] == 'to appear' && h['volume'].to_s.empty?
    b = w['biblio']
    h.delete('status')
    h['year'] = w['publication_year'] if w['publication_year']
    h['volume'] = b['volume']
    h['issue'] = b['issue'] unless b['issue'].to_s.empty?
    h['pages'] = pages_of(b) if pages_of(b)
    updated << h
    emit(h) + trail
  end
  txt = head + blocks.join
end
unless new_entries.empty?
  txt << "\n" unless txt.end_with?("\n")
  txt << "\n# Encontrados no OpenAlex em #{Date.today}\n"
  new_entries.each { |x| txt << emit(x) }
end
changed = !(new_entries.empty? && updated.empty?)
if changed && !DRY
  yload_text(txt) # garante que o YAML continua válido antes de gravar
  File.write(PUBS, txt)
end

# ---------- aviso ----------
edit = "https://github.com/#{REPO}/edit/main/_data/publications.yml"
ign = "https://github.com/#{REPO}/edit/main/_data/publications-ignore.yml"
body = []
if changed
  body << 'A busca semanal no OpenAlex atualizou a lista de publicações do site.'
  if new_entries.any?
    body << '' << "**Artigos acrescentados (#{new_entries.size}):**" << ''
    new_entries.each do |x|
      st = x['status'] ? ' · *to appear*' : ''
      body << "- #{x['title']}. *#{x['journal']}*, #{x['year']}#{st}. [DOI](https://doi.org/#{x['doi']}) · #{x['_members'].join(', ')}"
    end
  end
  if updated.any?
    body << '' << "**Artigos \"to appear\" que saíram num número da revista (#{updated.size}):**" << ''
    updated.each do |h|
      ref = [h['volume'], h['issue'] ? "(#{h['issue']})" : nil].compact.join
      ref += ", #{h['pages']}" if h['pages']
      body << "- #{h['title']}. *#{h['journal']}* #{ref}, #{h['year']}."
    end
  end
  body << '' << 'Se algo estiver errado (título, autores, revista ou artigo fora do período na UFG):'
  body << "- para corrigir, edite [`_data/publications.yml`](#{edit});"
  body << "- para remover um artigo, apague-o desse arquivo e acrescente o DOI em [`_data/publications-ignore.yml`](#{ign}), para que não volte."
  body << '' << 'Depois de conferir, pode fechar este aviso.'
  gh = new_entries.flat_map { |x| x['_github'] }.uniq
  body << '' << "cc #{gh.map { |g| '@' + g }.join(' ')}" if gh.any?
end

puts "#{new_entries.size} novo(s), #{updated.size} to appear atualizado(s)"
File.write(AVISO, body.join("\n") + "\n") if changed && !DRY
if ENV['GITHUB_OUTPUT']
  File.open(ENV['GITHUB_OUTPUT'], 'a') do |f|
    f.puts "mudou=#{changed}"
    f.puts "novos=#{new_entries.size}"
    f.puts "atualizados=#{updated.size}"
  end
end
puts body.join("\n") if DRY
