# perlschool.com

Source and static-site generator for the [Perl School](https://perlschool.com/)
publishing website. Perl School publishes practical Perl books in ebook and
paperback editions. The site presents the catalogue, authors, purchase links,
downloadable examples, and information for prospective authors.

The generator is written in Perl, uses DBIx::Class to read a checked-in SQLite
database, and renders HTML with Template Toolkit. GitHub Actions builds the
site and deploys it to GitHub Pages. There is no application server or database
connection at request time; purchases happen on external sites.

## Repository map

| Path | Purpose |
| --- | --- |
| `bin/build` | Build entry point; calls `PerlSchool::Build->new->run`. |
| `lib/PerlSchool/Build.pm` | Selects catalogue records, renders pages, copies assets, and creates the sitemap. |
| `lib/PerlSchool/Schema.pm` | SQLite connection and DBIx::Class schema. |
| `lib/PerlSchool/Schema/Result/` | Table mappings, relationships, book helpers, and JSON-LD data. |
| `lib/PerlSchool/Schema/ResultSet/` | Book and author query helpers. |
| `perlschool.db` | Current catalogue and schema; tracked in Git. |
| `perlschool.sql` | Historical, incomplete schema; cannot recreate the current database. |
| `migrations/` | Incremental SQL changes for older database copies. |
| `in/` | Page templates, including shared templates for all book detail pages. |
| `ttlib/` | Page wrapper, image/badge macros, redirect template, and sidebar fragment. |
| `static/` | Assets copied to the output: CSS, images, example archives, favicons, `CNAME`, and `.nojekyll`. |
| `data/` | HTML table-of-contents fragments that can be imported into book records. |
| `docs/` | Generated website; ignored by Git. This is build output, not project documentation. |
| `cpanfile` | CPAN dependencies. |
| `t/` | Tests for metadata text and rendered description attributes. |
| `.github/workflows/buildsite.yml` | Build and GitHub Pages deployment workflow. |

## Build and preview locally

Run commands from the repository root: templates, assets, the default database
path, and output path are relative to the working directory.

You need Perl and the dependencies in `cpanfile`. The result-set modules require
at least Perl 5.20; no supported-version matrix is defined. Install dependencies
with `cpanm` using your usual system or local-library installation setup:

```sh
cpanm --installdeps .
```

If you do not already have `.env`, copy the supplied sample:

```sh
cp .env.sample .env
```

It contains `PERLSCHOOL_DB=./perlschool.db`. The build loads `.env` through
`ENV::Util`, reads the `PERLSCHOOL_` configuration prefix, and passes the database
path to the schema. You can also set the database explicitly in the environment:

```sh
PERLSCHOOL_DB=./perlschool.db PERL5LIB=lib bin/build
```

With `.env` configured, the normal build command is:

```sh
PERL5LIB=lib bin/build
```

`PERL5LIB=lib` is necessary because `bin/build` adds `bin/lib` to its search path,
whereas the project modules live in the top-level `lib/` directory. A successful
build prints asset-copy messages and some diagnostic warnings, and writes to
`docs/`. It does not remove output left by earlier builds, so use a fresh output
directory when checking that removed books or routes have disappeared.

To preview, serve the output over HTTP; the site uses root-relative links:

```sh
python3 -m http.server 8000 --directory docs
```

Open `http://localhost:8000/`. Python is only needed for this preview command.
Canonical links and social-image URLs still point at `https://perlschool.com/`.

## How generation works

`PerlSchool::Build::run` performs these steps:

1. Generates the legacy route files for `/our-instructor/` and `/dmp/`.
2. Recursively copies `static/` into `docs/`.
3. Renders the home page, featuring the book with the latest publication date.
4. Renders `/books/<slug>/index.html` for each visible Perl School book.
5. Renders the authors page.
6. Renders `/books/`, `/about/`, `/contact/`, `/write/`, `/faq/`, and `/lpw/`.
7. Writes `sitemap.xml` from the canonical URLs collected while rendering pages.

The catalogue query requires both `is_perlschool_book = 1` and `is_live = 1`,
and orders by `pubdate` descending. A future publication date does not hide a
book: `Book::is_published` compares the date with the current time, and templates
show a “Coming soon” badge. A future-dated book can therefore be the home-page
feature. `/books/` displays the same selection alphabetically by title.

Authors are selected if they have any Perl School book and sorted by `sortname`.
The authors template separately filters their displayed books to live Perl
School titles. An author with only hidden titles can still appear without books.

Template Toolkit searches `in/` and `ttlib/` and wraps output in `page.tt`.
That wrapper adds navigation, metadata, recent-book cards, a mailing-list form,
and the footer for templates whose names contain `.html`; other templates pass
through without the HTML shell. Book and author models provide Schema.org
JSON-LD through `MooX::Role::JSON_LD`.

## Catalogue and content maintenance

The build reads catalogue content from `perlschool.db`; it does not import
`data/` automatically. Back up the database before editing it, and include the
updated database in the source change when publishing catalogue edits. The
`migrations/` directory contains incremental changes; there is still no complete
database-bootstrap workflow.

The main tables are:

| Table | Contents and relationships |
| --- | --- |
| `author` | Name, biography, and sort name; has many books. |
| `book` | Catalogue metadata, content, and visibility; belongs to an author through `author_id`. |
| `amazon_site` | Marketplace codes, domains, currencies, and ordering for the older link helpers. |
| `amazon_sales` | Monthly units, borrows, and pages read per book and marketplace; unused by the site build. |

Important book fields:

| Fields | Effect |
| --- | --- |
| `title`, `subtitle`, `slug`, `author_id` | Identity, detail-page URL, and author association. Keep slugs unique. |
| `pubdate`, `upddate` | Publication status, feature ordering, and optional latest-update date. |
| `is_live`, `is_perlschool_book` | Both must be true for a generated book detail page. |
| `blurb`, `description`, `toc`, `buy_blurb` | Summary, detailed description, contents, and purchase copy. These support HTML and are rendered without escaping. |
| `seo_description` | Optional plain-text summary for search and social metadata; a blank value falls back to a cleaned blurb. |
| `image` | Image basename, without an extension. |
| `leanpub_slug`, `amazon_asin`, `website`, `isbn` | External purchase, website, and ISBN links. |
| `examples` | Archive basename for `/examples/<value>.zip` and `.tar.gz`. |
| `highlights`, `has_paperback` | Colon-separated highlight badges and paperback-availability badge. |
| `kit_list` | Optional book-specific Kit signup-form identifier, replacing the general form on that book page. |

Book metadata uses `Book::meta_description`, which chooses a nonblank
`seo_description` or strips the blurb with HTML::Strip, decodes HTML entities,
and normalizes whitespace. It does not truncate descriptions. The template
escapes the result for the regular description, Open Graph, and Twitter meta
attributes, while the body keeps the rich HTML blurb.

The checked-in database already includes `seo_description`. To add it to an
older custom database, back up that database and apply this migration once:

```sh
sqlite3 -bail path/to/catalogue.db < migrations/001-add-book-seo-description.sql
```

The migration adds a nullable column without changing existing book fields.
The checked-in catalogue has an explicit summary for Data Munging with Perl;
other books use the fallback unless a summary is supplied.

To update a page's prose, edit its template in `in/`. To change shared layout or
metadata, edit `ttlib/page.tt`; image and badge helpers are in `ttlib/util.tt`.
Styles live in `static/css/heroic-features.css`. A new general page also needs an
entry in `_build_pages` in `Build.pm` to be generated and added to the sitemap.

For a new book, add its author/book records, cover assets, and any example
archives. The current image convention uses `static/images/<image>.webp`,
`<image>.png`, and `<image>-og.png` for social previews. The detail template
requests a JPG fallback, although the checked-in covers are PNG/WebP; supply
the JPG or account for that mismatch when changing images.

### Maintenance scripts

Unlike the build, scripts calling `Schema->get_schema` without an argument use
`PERLSCHOOL_DB_FILE` and do not load `.env`. For example:

```sh
PERLSCHOOL_DB_FILE=./perlschool.db PERL5LIB=lib bin/get_slug munging
PERLSCHOOL_DB_FILE=./perlschool.db PERL5LIB=lib bin/edit_extra perl-taster
```

| Script | Behavior |
| --- | --- |
| `bin/get_slug [title fragment]` | Lists matching titles/slugs, or all books if no fragment is supplied. |
| `bin/edit_extra <slug>` | Writes `data/<slug>.toc` and/or `.desc` HTML into the book's database record. Run from the root because the `.desc` existence check is relative. |
| `bin/make_links <ASIN>` | Prints Markdown links for the stored Amazon marketplaces. |
| `bin/make_amazon_btns [ASIN]` | Prints an older HTML button list; uses a default ASIN if omitted. |
| `bin/load_amazon` | Deletes and reloads all marketplace rows from embedded data; not needed to build the site. |
| `bin/mkclasses` | Regenerates ORM mappings from `perlschool.db` using `dbicdump` from `DBIx::Class::Schema::Loader`, an additional development dependency. |
| `bin/loaddata` | Intended pipe-delimited book importer; currently broken (see below). |

Generated schema/result files have a marked generated section and custom code
below it. Keep custom behavior below the marker when regenerating mappings.

## Deployment and external services

The workflow runs on pushes to `master` and through manual `workflow_dispatch`.
It installs CPAN dependencies, runs `PERL5LIB=lib bin/build`, uploads `docs/` as a
Pages artifact, and deploys that artifact in a separate job. It supplies
`PERLSCHOOL_DB` from a GitHub Actions repository variable; set that variable to
`./perlschool.db` to use the checked-in database. Pages deployment uses the
`github-pages` environment with `pages: write` and `id-token: write` permissions.
`static/CNAME` contains `perlschool.com`; `.nojekyll` is copied into the output.
The workflow runs the metadata tests before building. Run them locally with
`PERL5LIB=lib prove -v t`. Dependabot is configured for weekly GitHub Actions updates.

Browser-side integrations include Bootstrap from jsDelivr, Google Analytics,
AddToAny sharing, Kit mailing-list forms, and an embedded Google Form on `/lpw/`.
The navigation links to the separate cover-maker site. Amazon buttons are
populated by an external `amazon-store` JavaScript library loaded from
`cdn.davecross.co.uk`. The builder still constructs an `Amazon::Sites` object
with a UK affiliate code, but the current book template uses the JavaScript
integration instead. Its optional `site.amazon_tag` is not supplied by the
builder. The build itself does not fetch these browser-side services.

## Verified behavior and known limitations

Repository inspection and a build in a fresh temporary directory on
2026-10-02, using Perl 5.42.3 and already-installed dependencies, confirmed:

- The build exits successfully and generates 19 HTML files: nine book detail
  pages, the home page, seven general pages including authors, and two legacy
  route files. Static assets, `CNAME`, and `.nojekyll` are copied.
- The database contains 12 books, five authors, 13 marketplaces, and no sales
  rows. Nine books meet the site's visibility filters. SQLite's
  `PRAGMA integrity_check` returns `ok`.
- The sitemap contains 17 canonical URLs, but a leading blank line before the
  XML declaration causes strict XML parsing to fail. The wrapper introduces
  that whitespace even for non-HTML output.
- Legacy route files contain only a “Redirecting…” paragraph. `redirect.tt`
  does not match the wrapper's `.html` condition, so the meta-refresh logic in
  `page.tt` is never emitted. These files do not actually redirect browsers.
- `bin/loaddata` fails compilation because `$rs` is undeclared. It cannot be
  used as the current catalogue-loading procedure.
- `PRAGMA foreign_key_check` fails with a foreign-key mismatch: `amazon_sales`
  references `amazon_site.code`, which has no primary-key or unique constraint.
- `perlschool.sql` omits later columns and both Amazon tables. Use the tracked
  database as the current schema reference.
- The metadata change adds focused tests for description fallback, entities,
  escaping, and rendered book metadata. Broader generated-site validation for
  links, redirects, and XML is still absent. Some directly
  used modules, including `JSON`, `DateTime`, and `Moo`, are not explicitly
  declared in `cpanfile`; the successful local build does not verify dependency
  installation from scratch.

The limitations above remain outside the metadata-description change.
