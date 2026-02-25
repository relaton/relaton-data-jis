# frozen_string_literal: true

require "relaton/jis/data_fetcher"

FileUtils.rm_rf('data')
FileUtils.rm Dir.glob('index*')

Relaton::Jis::DataFetcher.fetch
