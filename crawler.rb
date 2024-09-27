# frozen_string_literal: true

require "relaton_jis"

FileUtils.rm_rf('data')
FileUtils.rm Dir.glob('index*')

RelatonJis::DataFetcher.fetch
