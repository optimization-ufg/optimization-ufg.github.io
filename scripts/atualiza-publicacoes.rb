# Busca no OpenAlex, pelo ORCID de cada professor, artigos de revista que ainda não estão em
# _data/publications.yml e os acrescenta ao fim do arquivo, no formato do site.
#
# Critério: artigo com DOI, publicado numa revista, a partir do ano de entrada do professor
# na UFG (campo "since" em _data/members.yml). DOIs listados em _data/publications-ignore.yml
# nunca são sugeridos.
#
# Uso: ruby scripts/atualiza-publicacoes.rb [--dry-run]
# Roda toda semana pelo GitHub Actions (.github/workflows/atualiza-publicacoes.yml), que abre um
# pull request com o resultado para alguém revisar.
require 'net/http'
require 'json'
require 'yaml'
require 'date'
require 'cgi'
require 'uri'

ROOT = File.expand_path('..', __dir__)
PUBS = File.join(ROOT, '_data', 'publications.yml')
DRY = ARGV.include?('--dry-run')

def yload(path)
  return nil unless File.exist?(path)
  YAML.safe_load(File.read(path, encoding: 'UTF-8'), permitted_classes: [Date]) || nil
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
  t = p['title'].to_s
  t.split(/\s+/).each_with_index do |w, i|
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

def q(v)
  s = v.to_s
  needs = s.empty? || s =~ /\A[\s\-?:,\[\]{}#&*!|>'"%@`]/ || s.include?(': ') || s.include?(' #') ||
          s.end_with?(':') || s =~ /\A[\d.]+\z/ || s =~ /\A(true|false|yes|no|null|on|off|~)\z/i
  needs ? s.to_json : s
end

# ---------- busca ----------
FIELDS = 'id,doi,title,publication_year,type,primary_location,locations,authorships,biblio'
found = {}
warnings = []

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
      doi = w['doi'].to_s.sub(%r{\Ahttps?://(dx\.)?doi\.org/}i, '').downcase.strip
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

# ---------- formatação ----------
entries = found.map do |doi, e|
  w = e['w']
  b = w['biblio'] || {}
  authors = (w['authorships'] || []).map do |a|
    orcid = a.dig('author', 'orcid').to_s.sub(%r{\Ahttps?://orcid\.org/}, '')
    (by_orcid[orcid] && by_orcid[orcid]['cite']) || cite_name(a.dig('author', 'display_name') || a['raw_author_name'])
  end
  pages = [b['first_page'], b['last_page']].compact.map(&:to_s).reject(&:empty?).uniq.join('–')
  {
    'year' => w['publication_year'],
    'status' => (b['volume'].to_s.empty? ? 'to appear' : nil),
    'authors' => authors.join('; '),
    'title' => sentence_case(e['title']),
    'journal' => journal_name(clean(e['loc'].dig('source', 'display_name')), journals),
    'volume' => b['volume'], 'issue' => b['issue'], 'pages' => (pages.empty? ? nil : pages),
    'doi' => doi,
    '_members' => e['members'].map { |m| m['name'] },
    '_github' => e['members'].map { |m| m['github'] }.compact
  }
end.sort_by { |x| [-x['year'].to_i, x['authors']] }

puts "#{entries.size} artigo(s) novo(s)"

body = []
if entries.any?
  body << "O OpenAlex tem #{entries.size} artigo(s) dos professores que ainda não estão no site."
  body << ''
  body << 'Antes de aprovar, confira em **Files changed**: título (só a primeira letra e nomes próprios em maiúscula), nomes dos autores no formato `Sobrenome, I.`, nome da revista e se o artigo é mesmo do período na UFG.'
  body << ''
  body << '- Para corrigir algo, edite o arquivo nesta página (⋯ → Edit file) antes de aprovar.'
  body << '- Para recusar um artigo, apague-o daqui e acrescente o DOI em `_data/publications-ignore.yml`, para que não volte a ser sugerido.'
  body << ''
  entries.each do |x|
    st = x['status'] ? ' · *to appear*' : ''
    body << "- **#{x['title']}**. #{x['journal']}, #{x['year']}#{st}. [doi](https://doi.org/#{x['doi']}) · #{x['_members'].join(', ')}"
  end
  gh = entries.flat_map { |x| x['_github'] }.uniq
  body << '' << "cc #{gh.map { |g| '@' + g }.join(' ')}" if gh.any?
end

unless DRY || entries.empty?
  txt = File.read(PUBS, encoding: 'UTF-8')
  txt << "\n" unless txt.end_with?("\n")
  txt << "\n# Encontrados no OpenAlex em #{Date.today}\n"
  entries.each do |x|
    first = true
    %w[year status authors title journal volume issue pages doi].each do |k|
      v = x[k]
      next if v.nil? || v.to_s.empty?
      v = %w[volume issue pages].include?(k) ? v.to_s.to_json : (k == 'year' ? v : q(v))
      txt << (first ? '- ' : '  ') << "#{k}: #{v}\n"
      first = false
    end
  end
  File.write(PUBS, txt)
  YAML.safe_load(File.read(PUBS, encoding: 'UTF-8'), permitted_classes: [Date]) # garante que o YAML continua válido
end

File.write(File.join(ROOT, 'pr-body.md'), body.join("\n") + "\n") unless DRY
if ENV['GITHUB_OUTPUT']
  File.open(ENV['GITHUB_OUTPUT'], 'a') do |f|
    f.puts "novos=#{entries.size}"
    f.puts "revisores=#{entries.flat_map { |x| x['_github'] }.uniq.join(',')}"
  end
end
puts body.join("\n") if DRY
