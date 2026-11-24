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

Toda segunda-feira, o GitHub procura no [OpenAlex](https://openalex.org), pelo ORCID de cada professor, artigos de revista que ainda não estão em `_data/publications.yml`. Só entram artigos publicados a partir do ano de entrada do professor na UFG (campo `since` em `_data/members.yml`).

Quando encontra artigos novos, ele abre um **pull request** (aba *Pull requests*) com os artigos já formatados. Nada vai para o site sem revisão:

1. Abra o pull request e confira a lista em **Files changed**: título (só a primeira letra e nomes próprios em maiúscula), autores no formato `Sobrenome, I.`, nome da revista e se o artigo é do período na UFG.
2. Para corrigir algo, edite o arquivo ali mesmo (⋯ → *Edit file*).
3. Para recusar um artigo, apague-o e acrescente o DOI em `_data/publications-ignore.yml`, para que ele não volte a ser sugerido.
4. Clique em **Merge pull request**. O site se atualiza em um ou dois minutos.

Enquanto um pull request estiver aberto, a busca semanal não faz nada, para não apagar correções em andamento. Para rodar a busca na hora: aba *Actions* → *Atualizar publicações* → *Run workflow*.

Avisos por e-mail: o GitHub avisa quem acompanha o repositório (botão **Watch** → *All activity*). Professores com o campo `github` em `_data/members.yml` também são marcados como revisores quando aparece um artigo deles.

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
