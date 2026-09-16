# frozen_string_literal: true

require "rails_helper"
require "zip"

RSpec.describe WulinAgent::ArchiveService do
  let(:user) { User.create!(email: "user-#{SecureRandom.hex(4)}@example.com", admin: true) }

  def build_zip(entries)
    buffer = StringIO.new
    buffer.set_encoding(Encoding::BINARY)
    Zip::OutputStream.write_buffer(buffer) do |zip|
      entries.each do |path, content|
        zip.put_next_entry(path)
        zip.write(content)
      end
    end
    buffer.string
  end

  def upload_zip(entries, filename: "export.zip")
    file = Rack::Test::UploadedFile.new(
      StringIO.new(build_zip(entries)),
      "application/zip",
      original_filename: filename
    )
    described_class.upload(file: file, user: user)
  end
  before { described_class.reset! }
  after { described_class.reset! }

  describe ".upload" do
    it "stores an uploaded zip and returns inject info" do
      result = upload_zip({"docs/readme.md" => "# Uploaded"})

      expect(result["archive_id"]).to be_present
      expect(result["file_count"]).to eq(1)
      expect(result["files"].first["path"]).to eq("docs/readme.md")
      expect(result["inject_mode"]).to eq("full")
      expect(result["inject_message"]).to include("Content included in the message")
    end

    it "accepts a single text file upload" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("plain text"),
        "text/plain",
        original_filename: "notes.txt"
      )

      result = described_class.upload(file: file, user: user)

      expect(result["archive_id"]).to be_present
      expect(result["file_count"]).to eq(1)
      expect(result["files"].first["path"]).to eq("notes.txt")
    end

    it "rejects unsupported file types" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("binary"),
        "image/png",
        original_filename: "photo.png"
      )

      result = described_class.upload(file: file, user: user)

      expect(result).to eq("error" => "file must be a .zip or a supported text file")
    end

    it "accepts a single csv upload" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("name,value\nfoo,1\n"),
        "text/csv",
        original_filename: "data.csv"
      )

      result = described_class.upload(file: file, user: user)

      expect(result["archive_id"]).to be_present
      expect(result["file_count"]).to eq(1)
      expect(result["inject_mode"]).to eq("full")
    end

    it "rejects invalid zip uploads" do
      result = upload_zip({"image.png" => "binary"})

      expect(result).to eq("error" => "no readable text files found")
    end

    it "rejects uploads whose text content exceeds the inject limit" do
      stub_const("WulinAgent::ArchiveService::MAX_INJECT_CHARS", 50)
      result = upload_zip(
        {
          "docs/readme.md" => "# Title",
          "docs/notes.txt" => "Some notes"
        }
      )

      expect(result["error"]).to include("exceeds the limit")
      expect(Dir.children(described_class.send(:storage_root))).to be_empty
    end

    it "ignores non-text files and path traversal entries" do
      result = upload_zip(
        {
          "docs/readme.md" => "# Hello",
          "docs/nested/notes.txt" => "notes",
          "image.png" => "binary",
          "../escape.txt" => "bad"
        }
      )

      expect(result["file_count"]).to eq(2)
      expect(result["files"].map { |file| file["path"] }).to eq(
        ["docs/nested/notes.txt", "docs/readme.md"]
      )
    end
  end

  describe ".build_context and .enrich_message" do
    let(:archive_id) do
      upload_zip(
        {
          "docs/readme.md" => "# Title",
          "docs/notes.txt" => "Some notes"
        }
      )["archive_id"]
    end

    it "injects full archive contents for small zips" do
      context = described_class.build_context(archive_id: archive_id, user: user)

      expect(context["mode"]).to eq("full")
      expect(context["text"]).to include("# Title")
      expect(context["text"]).to include("Some notes")
      expect(context["text"]).to include("archive_id: #{archive_id}")
      expect(context["injected_chars"]).to be > 0
    end

    it "prepends archive context to the user message" do
      enriched = described_class.enrich_message(
        "Summarize this",
        archive_id: archive_id,
        user: user
      )

      expect(enriched).to include("# Title")
      expect(enriched).to include("User message:\nSummarize this")
    end

    it "returns archive context when the user message is empty" do
      enriched = described_class.enrich_message("", archive_id: archive_id, user: user)

      expect(enriched).to include("# Title")
      expect(enriched).not_to include("User message:")
    end

    it "returns an error when content exceeds the inject limit" do
      id = upload_zip(
        {
          "docs/readme.md" => "# Title",
          "docs/notes.txt" => "Some notes"
        }
      )["archive_id"]
      stub_const("WulinAgent::ArchiveService::MAX_INJECT_CHARS", 50)
      context = described_class.build_context(archive_id: id, user: user)

      expect(context["error"]).to include("exceeds the limit")
    end

    it "returns inject info for a stored archive" do
      info = described_class.inject_info(archive_id: archive_id, user: user)

      expect(info["inject_mode"]).to eq("full")
      expect(info["inject_message"]).to include("Content included in the message")
    end
  end
end
