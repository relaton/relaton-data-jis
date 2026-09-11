# relaton-data-jis

The JIS bibliographic corpus, crawled from https://webdesk.jsa.or.jp by
`crawler.rb`, which drives the JIS flavor of the `relaton` gem.

Branch `v2` is the published branch. The released `relaton-jis` gem reads
`https://raw.githubusercontent.com/relaton/relaton-data-jis/v2/index-v1.zip`.

## Two index files

| File | Rows | Written by | Read by |
|---|---|---|---|
| `index-v2.yaml` / `.zip` | `Pubid::Jis::Identifier`, `_type: pubid:jis:*` | `Relaton::Jis::DataFetcher` | relaton v3 |
| `index-v1.yaml` / `.zip` | plain strings, e.g. `JIS A 0001:1999` | `build_index_v1.rb`, here | released `relaton-jis` |

Each index has one row for each file in `data/` (21,496 on 2026-09-10).
`relaton/support`'s shared `crawler.yml` zips every changed `index*.yaml` and
commits the yaml and the zip together. Nothing here zips.

## `index-v1` is built from `data/`, not from `index-v2`

The relaton branch `feat/jis-drop-index-v1` stops the `index-v1` write in the
gem. `IndexV1.write` reads the crawled documents, as relaton-data-xsf does:

1. It does not depend on what pubid accepts.
2. It needs no decline path keyed on `Relaton::Jis::INDEXFILE`. It works with a
   relaton that still writes `index-v1` (the build overwrites it with the same
   rows) and with one that does not.
3. It never touches the fetcher's `:jis` pool entry. `IndexV1::POOL_KEY` is
   `:JIS_V1`. `Relaton::Index::Pool#type` upcases its key, so `:jis` and `:JIS`
   are one entry.

The cost: `IndexV1.row_id` restates the id rule of
`Relaton::Jis::DataFetcher#save_doc` (the primary docidentifier) in a second
place. `spec/build_index_v1_spec.rb` pins it against the real corpus.

## A zero-result crawl must fail the job

`crawler.rb` deletes `data/` and both indexes **before** the fetch. The shared
`crawler.yml` stages deletions (`git add -u data/`), commits, and pushes. A
fetch that returns nothing (a failed initial POST makes `fetch` return early)
would publish the removal of the whole corpus.

`IndexV1.write` returns nil and writes no file on an empty `data/`, and also
when no document gives a usable id (a change to the YAML shape of
`docidentifier` does that to every document). `crawler.rb` ends in
`abort ... if rows.nil?`. The non-zero exit fails the job, and the push step
does not run. `spec/crawler_sources_spec.rb` pins it. Do not remove that line,
and do not rescue around it.

## Do not name a file `index*`

`crawler.rb` removes `index-v*.{yaml,zip}`. A bare `index*` glob also matches a
Ruby file beside it, and relaton-data-bipm deleted its own source that way.
Keep Ruby files verb-named (`build_index_v1.rb`).

## Specs

`bundle exec rspec`. There is no Rakefile, no rubocop config, and no CI job for
the specs. The run takes 15 to 35 s: the acceptance example builds `index-v1`
from the real `data/` and compares it with the committed `index-v1.yaml`, row
for row.

`spec/spec_helper.rb` requires `build_index_v1.rb`, never `crawler.rb`, which
deletes `data/` on load. `spec/crawler_sources_spec.rb` reads `crawler.rb` as
source text, without the comment lines.

Assert warnings on `Relaton.logger_pool`, not on `Relaton::Index::Util`:
`Util#method_missing` forwards `warn` to the pool, and a stub on `Util` is
never reached.

## Dependency pins

`Gemfile` pins `relaton` and `pubid` to `main` of their git repositories.
Bundler reads a git gem's gemspec, never its Gemfile, so relaton's own pubid
pin does not reach this bundle. `Gemfile.lock` is git-ignored, so CI resolves
both fresh on every crawl. A stale local lock can fail `bundle install`; run
`bundle update pubid relaton`. Check with
`bundle list | grep -E "relaton |pubid "`.
