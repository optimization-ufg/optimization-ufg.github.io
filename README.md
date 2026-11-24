# Site do Continuous Optimization Group (IME/UFG)

O site é gerado pelo GitHub Pages a partir dos arquivos deste repositório. Para mudar o conteúdo, basta editar um arquivo aqui no GitHub (ícone de lápis → **Commit changes**). O site se atualiza sozinho em um ou dois minutos.

## Onde está cada coisa

| O que mudar | Arquivo |
|---|---|
| Professores, alunos, egressos | `_data/members.yml` |
| Publicações | `_data/publications.yml` |
| Seminários (um arquivo por semestre) | `_seminars/2026-1.md`, `_seminars/2026-2.md`, … |
| Texto da página inicial (apresentação, áreas de pesquisa, contato) | `index.html` |
| Fotos | `assets/img/` |
| Links | `links.html` |
| Visual (cores, fontes) | `assets/css/style.css` |

Os arquivos `.yml` e o cabeçalho dos `.md` usam YAML: a indentação (espaços, nunca tab) importa, e cada item de lista começa com `- `. Se um texto tiver dois-pontos seguidos de espaço (`: `) ou começar com aspas, coloque-o entre aspas duplas.

## Acrescentar uma publicação

Em `_data/publications.yml`, copie um item existente e ajuste. A ordem no arquivo não importa: a página agrupa por ano e ordena pelos autores.

```yaml
- year: 2026
  authors: Ferreira, O. P.; Prudente, L. F.; Silva, J. A.
  title: Título do artigo em sentence case
  journal: SIAM Journal on Optimization
  volume: 36
  issue: 2
  pages: 1–25
  doi: 10.1137/xxxxxxx
```

- Autores no formato `Sobrenome, I. I.`, separados por `; `.
- Nome da revista por extenso.
- Artigo aceito que ainda não saiu num número da revista: acrescente `status: to appear` (e omita volume e páginas, se não houver).
- Sem DOI, use `url:` com o endereço do artigo.

## Publicações automáticas (OpenAlex)

Toda segunda-feira, o GitHub consulta o [OpenAlex](https://openalex.org) pelo ORCID de cada professor e atualiza `_data/publications.yml` sozinho:

- acrescenta artigos de revista que ainda não estão no site, publicados a partir do ano de entrada do professor na UFG (campo `since` em `_data/members.yml`);
- completa volume, número e páginas dos artigos marcados `to appear` que já saíram num número da revista.

As mudanças vão direto para o site. A cada atualização, o GitHub abre um aviso na aba *Issues* com a lista do que mudou, e quem acompanha o repositório recebe por e-mail (botão **Watch** → *All activity*). Professores com o campo `github` em `_data/members.yml` também são marcados no aviso quando aparece um artigo deles.

Se algo sair errado:

- para corrigir título, autores ou revista, edite `_data/publications.yml`;
- para remover um artigo (fora do período na UFG, duplicado etc.), apague-o desse arquivo e acrescente o DOI em `_data/publications-ignore.yml`, para que ele não volte.

Depois de conferir, feche o aviso. Para rodar a busca na hora: aba *Actions* → *Atualizar publicações* → *Run workflow*.

A busca depende do ORCID de cada professor estar atualizado. No ORCID, a opção que mantém tudo em dia é autorizar a Crossref (*Add works* → *Search & link* → Crossref), que envia sozinha os artigos novos com DOI.

## Acrescentar um seminário

Para um semestre novo, crie `_seminars/2026-2.md` copiando um existente. Cada palestra:

```yaml
  - date: 2026-08-20
    time: "14:00–15:00"
    speaker: Nome do Palestrante
    affiliation: IME/UFG
    title: Título da palestra
    abstract: |
      Primeiro parágrafo do resumo.

      Segundo parágrafo (separe parágrafos com uma linha em branco).
```

`time`, `affiliation` e `abstract` são opcionais. O semestre aparece sozinho na página Seminars, e as próximas palestras aparecem na página inicial. Fórmulas em LaTeX entre `$...$` são exibidas como matemática.

## Acrescentar um membro ou egresso

Em `_data/members.yml`, nas seções `faculty`, `phd_students`, `phd_graduates`, `masters_graduates` etc. Para professores: `orcid` é só o número (`0000-0000-0000-0000`) e `scholar` é só o código que vem depois de `user=` no endereço do Google Scholar.

- `since` é o ano de entrada na UFG, usado pela busca automática de publicações. `github` (opcional) é o usuário no GitHub, para receber aviso de artigos novos.
- `cite` é o nome como aparece nas publicações (`Prudente, L. F.`). Com ele, o nome fica em negrito na lista de publicações, entra no filtro por membro e o cartão do professor mostra quantos artigos há no site.
- Foto (opcional): envie uma imagem quadrada para `assets/img/people/` e acrescente `photo: /assets/img/people/nome.jpg`. Sem foto, o cartão mostra as iniciais.

## Testar antes de publicar (opcional)

Quem tiver Ruby e Jekyll instalados pode rodar `jekyll serve` na pasta do repositório e abrir http://localhost:4000. Não é necessário para editar pelo GitHub.
