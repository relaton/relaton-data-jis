# frozen_string_literal: true

source "https://rubygems.org"

# relaton is now a single unpublished gem in the relaton/relaton monorepo — the
# per-flavor gemspecs this file used to glob (relaton-jis, relaton-iso,
# relaton-bib, relaton-core, relaton-index, relaton-logger) are gone from
# gems/*/, so the old glob form no longer resolves. Pull it from main (HTTPS so
# the crawler GH action can clone the public repo anonymously, without an SSH
# key).
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"

# pubid 2.x is unpublished; pull the v2 line from main. (The old
# `rt-new-lutaml-model` pin broke once that branch was deleted upstream —
# `bundle` exits 11 with "Revision rt-new-lutaml-model does not exist".)
gem "pubid", git: "https://github.com/metanorma/pubid.git", branch: "main"
