# frozen_string_literal: true

require "date"
require "yaml"
require "relaton/index"

#
# The legacy `index-v1`, built from the crawled documents in `data/`.
#
# `Relaton::Jis::DataFetcher` writes only `index-v2`: its rows are
# `Pubid::Jis::Identifier` objects serialized to a `_type: pubid:jis:*` hash.
# The released `relaton-jis` gem still fetches `index-v1.zip` from this
# repository's `v2` branch, so this repository keeps producing it.
#
# It reads `data/`, not the `index-v2` the fetch just wrote, as
# relaton-data-xsf does: the rebuild does not depend on what pubid accepts,
# needs no decline path keyed on `Relaton::Jis::INDEXFILE`, and never touches
# the fetcher's `:jis` pool entry.
#
# The cost: {.row_id} restates the id rule of
# `Relaton::Jis::DataFetcher#save_doc` in a second place, where it can drift
# from the fetcher. `spec/build_index_v1_spec.rb` pins it against the real
# corpus.
#
# Nothing here zips. relaton/support's shared `crawler.yml` zips every
# `index*.yaml` that changed and commits the yaml and the zip together.
#
module IndexV1
  FILE = "index-v1.yaml"
  DATA_GLOB = "data/*.yaml"

  # A pool key of its own, so these plain strings never land in the
  # pubid-typed `:jis` entry the fetcher fills. `Relaton::Index::Pool#type`
  # upcases the key, so `:jis` and `:JIS` are one entry and this is not.
  POOL_KEY = :JIS_V1

  class << self
    #
    # The `index-v1` row id of one crawled document: the primary
    # docidentifier, or the first one when none is marked primary. The same
    # string `Relaton::Jis::DataFetcher#save_doc` parses into the v2 row.
    #
    # @param [Hash] doc a crawled document, as loaded from `data/`
    #
    # @return [String, nil] the row id, e.g. "JIS A 0001:1999", or nil
    #
    def row_id(doc)
      ids = doc["docidentifier"]
      return nil unless ids.is_a?(Array) && ids.any?

      (ids.detect { |i| i["primary"] } || ids.first)["content"]
    end

    #
    # Write `index-v1.yaml` from the documents the fetch wrote to `data/`.
    #
    # Declines on an empty corpus, and when no document gives a usable id.
    # `crawler.rb` deletes the index files before every crawl, so either case
    # would otherwise replace the published `index-v1.yaml` with `--- []`.
    # The second case is the drift risk above: a change to the YAML shape of
    # `docidentifier` breaks {.row_id} for every document, while the fetch
    # still writes all of `data/`.
    #
    # @return [Integer, nil] rows written, or nil if it declined and wrote
    #   no file
    #
    def write
      files = Dir.glob(DATA_GLOB).sort
      return nil if files.empty?

      index = Relaton::Index.find_or_create(POOL_KEY, file: FILE)
      # Build from scratch: a pooled Type outlives the file deletion in
      # crawler.rb, and `add_or_update` would merge into an earlier build.
      index.remove_all
      indexed = 0
      files.each do |file|
        # `[Date, Time]` is insurance: no document in today's corpus carries an
        # unquoted date. It keeps a serializer change that starts to write one
        # from failing the whole crawl at publish time.
        id = row_id(YAML.safe_load_file(file, permitted_classes: [Date, Time]))
        if id.nil?
          Relaton::Index::Util.warn "No docidentifier in #{file}; not indexed"
          next
        end
        index.add_or_update id, file
        indexed += 1
      end
      if indexed.zero?
        Relaton::Index::Util.warn "No document in #{DATA_GLOB} has a usable " \
                                  "id; #{FILE} not written"
        return nil
      end
      index.save

      written = index.index.size
      # `add_or_update` keys on the id, so two documents sharing one docid
      # publish one row. The ids are unique in today's corpus.
      if written < indexed
        Relaton::Index::Util.warn "#{indexed - written} of #{indexed} " \
                                  "documents collapsed onto an existing " \
                                  "index-v1 row"
      end
      written
    end
  end
end
