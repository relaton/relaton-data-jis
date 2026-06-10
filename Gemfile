# frozen_string_literal: true

source "https://rubygems.org"

# relaton-jis now lives in the relaton/relaton monorepo. Pull it and its
# unpublished 2.2.x sibling gems from the monorepo's main branch (HTTPS so the
# crawler GH action can clone the public repo anonymously, without an SSH key).
git "https://github.com/relaton/relaton.git", branch: "main", glob: "gems/*/*.gemspec" do
  gem "relaton-jis"
  gem "relaton-iso"
  gem "relaton-bib"
  gem "relaton-core"
  gem "relaton-index"
  gem "relaton-logger"
end

# pubid 2.x is unpublished; track the lutaml-model branch.
gem "pubid", git: "https://github.com/metanorma/pubid.git", branch: "rt-new-lutaml-model"
