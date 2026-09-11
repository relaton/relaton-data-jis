# frozen_string_literal: true

require "fileutils"
require "relaton/jis/data_fetcher"
require_relative "build_index_v1"

FileUtils.rm_rf("data")
# Narrower than 'index*', which would also match a Ruby file named index*.rb
# next to it -- the crawler would then delete its own source.
# relaton-data-bipm hit that bug; spec/crawler_sources_spec.rb guards it here.
FileUtils.rm Dir.glob("index-v*.{yaml,zip}")

# Writes data/ and index-v2.yaml. A relaton that still writes index-v1 also
# writes it here; the build below replaces it with the same rows.
Relaton::Jis::DataFetcher.fetch

# The released relaton-jis gem still reads index-v1.zip from this branch, so
# build it from the data/ the fetch just wrote. See build_index_v1.rb.
rows = IndexV1.write

# The deletions above already happened, and relaton/support's crawler.yml
# stages deletions and pushes them. A fetch that returned nothing (for example,
# a failed initial POST to webdesk.jsa.or.jp, which makes `fetch` return early)
# would publish the removal of the whole corpus. IndexV1.write also declines
# when no document gives a usable id. A non-zero exit fails the job, and GitHub
# Actions then skips the push step.
abort "No document indexed; refusing to publish an empty corpus" if rows.nil?
