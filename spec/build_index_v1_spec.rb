# frozen_string_literal: true

RSpec.describe IndexV1 do
  describe ".row_id" do
    # The primary entry is NOT first here on purpose. If it is first, this
    # example cannot tell `detect { primary }` from a plain `first`.
    it "takes the primary docidentifier, wherever it sits" do
      doc = { "docidentifier" => [{ "content" => "not primary" },
                                  { "content" => "JIS A 0001:1999",
                                    "primary" => true }] }
      expect(described_class.row_id(doc)).to eq "JIS A 0001:1999"
    end

    it "falls back to the first when none is marked primary" do
      doc = { "docidentifier" => [{ "content" => "JIS A 0001:1999" },
                                  { "content" => "JIS A 0002:1999" }] }
      expect(described_class.row_id(doc)).to eq "JIS A 0001:1999"
    end

    it "returns nil when there is no docidentifier" do
      expect(described_class.row_id({})).to be_nil
      expect(described_class.row_id({ "docidentifier" => [] })).to be_nil
    end

    it "returns nil when the entry carries no content" do
      expect(described_class.row_id({ "docidentifier" => [{ "type" => "JIS" }] }))
        .to be_nil
    end
  end

  describe ".write" do
    around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

    def write_doc(name, id)
      FileUtils.mkdir_p "data"
      body = { "docidentifier" => [{ "content" => id, "primary" => true }] }
      File.write "data/#{name}", body.to_yaml
    end

    # `crawler.rb` deletes `index-v1.yaml` before every crawl. A crawl that
    # fetched nothing would otherwise replace the published file with `--- []`.
    it "declines when data/ is missing" do
      expect(described_class.write).to be_nil
      expect(File).not_to exist(IndexV1::FILE)
    end

    it "declines when data/ holds no document" do
      FileUtils.mkdir_p "data"
      expect(described_class.write).to be_nil
      expect(File).not_to exist(IndexV1::FILE)
    end

    # The fetcher reads the id from the Ruby object, and `row_id` reads it
    # from the YAML. If the YAML shape changes, the fetch still writes all of
    # `data/`, but no document gives a row. Returning 0 would pass the
    # `rows.nil?` guard in `crawler.rb` and publish `--- []`.
    it "declines when no document in data/ has a usable id" do
      FileUtils.mkdir_p "data"
      File.write "data/a.yaml", { "title" => "no docidentifier" }.to_yaml
      File.write "data/b.yaml", { "docidentifier" => [] }.to_yaml
      allow(Relaton.logger_pool).to receive(:warn)
      expect(described_class.write).to be_nil
      expect(File).not_to exist(IndexV1::FILE)
      expect(Relaton.logger_pool)
        .to have_received(:warn).with(/no document .* usable id/i, "relaton-index")
    end

    context "with a corpus" do
      before do
        write_doc "jis-b-0001-2019.yaml", "JIS B 0001:2019"
        write_doc "jis-a-0001-1999.yaml", "JIS A 0001:1999"
      end

      it "writes one row per document" do
        expect(described_class.write).to eq 2
        expect(rows.map { |r| r[:id] })
          .to contain_exactly("JIS A 0001:1999", "JIS B 0001:2019")
        expect(rows.map { |r| r[:file] })
          .to contain_exactly("data/jis-a-0001-1999.yaml",
                              "data/jis-b-0001-2019.yaml")
      end

      # The rows follow the sorted file names, not the order the file system
      # lists them in. The same `data/` always gives the same file.
      it "writes the rows in file-name order" do
        described_class.write
        expect(rows.map { |r| r[:file] })
          .to eq %w[data/jis-a-0001-1999.yaml data/jis-b-0001-2019.yaml]
      end

      it "writes only the id and file keys" do
        described_class.write
        expect(rows.map(&:keys)).to all eq %i[id file]
      end

      # `index-v1` has no `pubid_class:`. A pubid hash here does not
      # deserialize in the released relaton-jis gem.
      it "stores plain strings, not pubid hashes" do
        described_class.write
        expect(rows.map { |r| r[:id] }).to all be_a(String)
      end

      # A pooled Type outlives the file deletion in `crawler.rb`, so without
      # `remove_all` a second run merges the rows of the previous run.
      it "rebuilds from scratch rather than merging a previous run" do
        described_class.write
        FileUtils.rm "data/jis-b-0001-2019.yaml"
        expect(described_class.write).to eq 1
        expect(rows.map { |r| r[:id] }).to contain_exactly("JIS A 0001:1999")
      end
    end

    # Asserted on `Relaton.logger_pool`, not on `Relaton::Index::Util`.
    # `Util` has no `warn` of its own: `Kernel#warn` is a private method on the
    # module object, so an explicit-receiver call goes to `Util`'s
    # `method_missing`, which forwards to the pool. A stub on `Util` gets
    # that private visibility and the call never reaches it.
    it "skips a document with no usable id, and warns" do
      write_doc "jis-a-0001-1999.yaml", "JIS A 0001:1999"
      File.write "data/broken.yaml", { "title" => "no docidentifier" }.to_yaml
      expect(Relaton.logger_pool)
        .to receive(:warn).with(/broken\.yaml/, "relaton-index")
      expect(described_class.write).to eq 1
      expect(rows.map { |r| r[:id] }).to contain_exactly("JIS A 0001:1999")
    end

    # `add_or_update` keys on the id, so the second document replaces the
    # first and adds no row. That loss is silent unless the build warns.
    it "warns when two documents share a docidentifier" do
      write_doc "jis-a-0001-1999.yaml", "JIS A 0001:1999"
      write_doc "jis-a-0001-1999-dup.yaml", "JIS A 0001:1999"
      expect(Relaton.logger_pool)
        .to receive(:warn).with(/1 of 2 documents collapsed/, "relaton-index")
      expect(described_class.write).to eq 1
    end

    def rows
      YAML.safe_load(File.read(IndexV1::FILE), permitted_classes: [Symbol])
    end
  end

  # The acceptance test. Build `index-v1` from the real committed `data/` and
  # require it to be the published file, row for row. Nothing smaller proves
  # that all documents are kept, and any change to `row_id` has to keep it
  # green. It reads about 21,500 files, so it takes about 20 seconds.
  describe "the published corpus" do
    around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

    before { FileUtils.ln_s File.join(REPO_ROOT, "data"), "data" }

    let(:published) do
      YAML.safe_load(File.read(File.join(REPO_ROOT, IndexV1::FILE)),
                     permitted_classes: [Symbol])
    end

    it "reproduces every published row, one for each document" do
      count = described_class.write
      built = YAML.safe_load(File.read(IndexV1::FILE),
                             permitted_classes: [Symbol])

      expect(count).to eq Dir.glob(File.join(REPO_ROOT, "data/*.yaml")).size
      expect(built.size).to eq count
      # Sorted, and not `contain_exactly`, which compares 21,500 rows pairwise
      # and gives a diff nobody can read on failure.
      by_file = ->(rows) { rows.sort_by { |r| r[:file] } }
      expect(by_file.call(built)).to eq by_file.call(published)
    end
  end
end
