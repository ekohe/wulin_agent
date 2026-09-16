# frozen_string_literal: true

require "zip"

module WulinAgent
  class ArchiveService
    class ArchiveError < StandardError; end

    MAX_ZIP_BYTES = 50 * 1024 * 1024
    MAX_UNCOMPRESSED_BYTES = 200 * 1024 * 1024
    MAX_FILES = 500
    MAX_INJECT_CHARS = 200_000
    TTL = 1.hour

    TEXT_EXTENSIONS = %w[
      .md .txt .json .yaml .yml .csv .tsv .xml .html .htm
      .rb .py .js .ts .jsx .tsx .css .scss .sql .log .ini .cfg .conf
      .env .toml .rst .adoc .sh .bash .zsh .php .go .rs .java .vue
    ].freeze

    MAX_SINGLE_FILE_BYTES = MAX_INJECT_CHARS

    class << self
      def upload(file:, user:)
        return error("file is required") if file.blank?

        cleanup_expired!
        if zip_upload?(file)
          store_from_bytes(file.read, user: user, source_url: file.original_filename.to_s)
        elsif text_upload?(file)
          store_from_text_file(file, user: user)
        else
          error("file must be a .zip or a supported text file")
        end
      rescue ArchiveError => e
        error(e.message)
      rescue StandardError
        error("failed to upload file")
      end

      def reset!
        FileUtils.rm_rf(storage_root) if Dir.exist?(storage_root)
      end

      def build_context(archive_id:, user:)
        meta, root = authorize!(archive_id, user)
        files = meta.fetch("files")
        label = meta["source_url"].presence || "archive"

        header = "[Attached file(s): #{label}, archive_id: #{archive_id}, #{files.size} text file#{'s' unless files.size == 1}]"
        sections = []
        total = header.length

        files.each do |file_meta|
          content = read_raw_text(root, file_meta["path"])
          return error("file is not valid UTF-8 text") unless content

          section = "### #{file_meta['path']}\n\n#{content}"
          separator = sections.empty? ? 2 : 7
          if total + separator + section.length > MAX_INJECT_CHARS
            return error(too_large_message)
          end

          sections << section
          total += separator + section.length
        end

        text = sections.empty? ? header : "#{header}\n\n#{sections.join("\n\n---\n\n")}"
        {
          "mode" => "full",
          "text" => text,
          "file_count" => files.size,
          "injected_chars" => total
        }
      rescue ArchiveError => e
        error(e.message)
      end

      def inject_info(archive_id:, user:)
        meta, = authorize!(archive_id, user)
        if meta["inject_mode"].present? && meta["inject_message"].present?
          return meta.slice("inject_mode", "inject_message")
        end

        inject_fields_from(build_context(archive_id: archive_id, user: user))
          .slice("inject_mode", "inject_message")
      rescue ArchiveError => e
        {
          "inject_mode" => "error",
          "inject_message" => "Content not injected: #{e.message}"
        }
      end

      def attachment_metadata(archive_id:, user:)
        meta, = authorize!(archive_id, user)
        inject_info(archive_id: archive_id, user: user).merge(
          "archive_id" => archive_id,
          "archive_filename" => File.basename(meta["source_url"].to_s),
          "archive_file_count" => meta.fetch("files").size
        )
      rescue ArchiveError => e
        {
          "archive_id" => archive_id,
          "inject_mode" => "error",
          "inject_message" => "Content not injected: #{e.message}"
        }
      end

      def enrich_message(message, archive_id:, user:)
        return message.to_s if archive_id.blank?

        context = build_context(archive_id: archive_id, user: user)
        log_inject_context(archive_id, context)
        return message.to_s if context["error"]

        user_part = message.to_s.strip
        archive_text = context["text"]
        if user_part.empty?
          archive_text
        else
          "#{archive_text}\n\n---\n\nUser message:\n#{user_part}"
        end
      end

      private

      def storage_root
        Rails.root.join("tmp/wulin_agent/archives")
      end

      def archive_dir(archive_id)
        storage_root.join(archive_id.to_s)
      end

      def meta_path(archive_id)
        archive_dir(archive_id).join("meta.json")
      end

      def store_from_bytes(zip_bytes, user:, source_url:)
        raise ArchiveError, "archive too large" if zip_bytes.bytesize > MAX_ZIP_BYTES

        archive_id = SecureRandom.uuid
        root = archive_dir(archive_id)
        FileUtils.mkdir_p(root)

        files = extract_zip(zip_bytes, root)
        raise ArchiveError, "no readable text files found" if files.empty?

        write_meta(
          archive_id,
          user_id: user.id,
          source_url: source_url,
          files: files,
          created_at: Time.current.iso8601
        )

        context = build_context(archive_id: archive_id, user: user)
        if context["error"]
          FileUtils.rm_rf(root)
          return context
        end

        inject = inject_fields_from(context)
        write_meta(archive_id, read_meta(archive_id).merge(inject))

        {
          "archive_id" => archive_id,
          "file_count" => files.size,
          "files" => files.map { |file| file.slice("path", "size") }
        }.merge(inject.slice("inject_mode", "inject_message"))
      end

      def store_from_text_file(file, user:)
        filename = file.original_filename.to_s
        path = normalize_path(File.basename(filename))
        raise ArchiveError, "invalid filename" unless path
        raise ArchiveError, "unsupported file type" unless text_file?(path)

        bytes = file.read
        raise ArchiveError, "file too large" if bytes.bytesize > MAX_SINGLE_FILE_BYTES

        content = bytes.dup.force_encoding(Encoding::UTF_8)
        raise ArchiveError, "file is not valid UTF-8 text" unless content.valid_encoding?

        archive_id = SecureRandom.uuid
        root = archive_dir(archive_id)
        FileUtils.mkdir_p(root)
        File.binwrite(File.join(root, path), bytes)

        files = [{"path" => path, "size" => bytes.bytesize}]
        write_meta(
          archive_id,
          user_id: user.id,
          source_url: filename,
          files: files,
          created_at: Time.current.iso8601
        )

        context = build_context(archive_id: archive_id, user: user)
        if context["error"]
          FileUtils.rm_rf(root)
          return context
        end

        inject = inject_fields_from(context)
        write_meta(archive_id, read_meta(archive_id).merge(inject))

        {
          "archive_id" => archive_id,
          "file_count" => 1,
          "files" => files.map { |entry| entry.slice("path", "size") }
        }.merge(inject.slice("inject_mode", "inject_message"))
      end

      def extract_zip(zip_bytes, root)
        files = []
        total_uncompressed = 0

        Zip::File.open_buffer(zip_bytes) do |zip|
          zip.each do |entry|
            next if entry.directory?

            normalized = normalize_path(entry.name)
            next unless normalized
            next unless text_file?(normalized)

            total_uncompressed += entry.size
            raise ArchiveError, "uncompressed archive too large" if total_uncompressed > MAX_UNCOMPRESSED_BYTES

            files << {"path" => normalized, "size" => entry.size}
            raise ArchiveError, "too many files" if files.size > MAX_FILES

            target = File.join(root.to_s, normalized)
            FileUtils.mkdir_p(File.dirname(target))
            entry.get_input_stream do |input|
              File.binwrite(target, input.read)
            end
          end
        end

        files.sort_by { |file| file["path"] }
      end

      def normalize_path(path)
        clean = path.to_s.tr("\\", "/").delete_prefix("/")
        return nil if clean.empty?
        return nil if clean.include?("..")
        return nil unless clean.match?(/\A[\w.\-\/]+\z/)

        clean
      end

      def text_file?(path)
        TEXT_EXTENSIONS.include?(File.extname(path).downcase)
      end

      def zip_upload?(file)
        filename = file.original_filename.to_s.downcase
        filename.end_with?(".zip")
      end

      def text_upload?(file)
        text_file?(file.original_filename.to_s)
      end

      def too_large_message
        limit_kb = (MAX_INJECT_CHARS / 1024.0).round
        "Text content exceeds the limit (~#{limit_kb} KB). " \
          "Reduce the number or size of files."
      end

      def inject_fields_from(source)
        if source["error"]
          return {
            "inject_mode" => "error",
            "inject_message" => source["error"]
          }
        end

        chars = source["injected_chars"].to_i
        files = source["file_count"].to_i
        size_label =
          if chars >= 1024
            "~#{(chars / 1024.0).round(1)} KB"
          else
            "#{chars} chars"
          end
        file_label = files == 1 ? "1 file" : "#{files} files"
        {
          "inject_mode" => "full",
          "inject_message" =>
            "Content included in the message (#{size_label}, #{file_label})."
        }
      end

      def log_inject_context(archive_id, context)
        if context["error"]
          Rails.logger.warn("[wulin_agent] archive=#{archive_id} inject failed: #{context['error']}")
          return
        end

        Rails.logger.info(
          "[wulin_agent] archive=#{archive_id} inject_mode=#{context['mode']} " \
          "files=#{context['file_count']} chars=#{context['injected_chars']}"
        )
      end

      def read_raw_text(root, path)
        normalized = normalize_path(path.to_s)
        return nil unless normalized

        full_path = File.expand_path(File.join(root, normalized))
        return nil unless File.file?(full_path)
        return nil unless full_path.start_with?("#{root}/")

        content = File.read(full_path, mode: "rb").force_encoding(Encoding::UTF_8)
        return nil unless content.valid_encoding?

        content
      end

      def write_meta(archive_id, data)
        File.write(meta_path(archive_id), JSON.generate(data))
      end

      def read_meta(archive_id)
        path = meta_path(archive_id)
        return nil unless File.file?(path)

        JSON.parse(File.read(path))
      end

      def authorize!(archive_id, user)
        meta = read_meta(archive_id)
        raise ArchiveError, "archive not found" unless meta
        raise ArchiveError, "archive not found" unless meta["user_id"] == user.id

        [meta, archive_dir(archive_id).to_s]
      end

      def cleanup_expired!
        return unless Dir.exist?(storage_root)

        cutoff = Time.current - TTL
        Dir.children(storage_root).each do |archive_id|
          meta = read_meta(archive_id)
          next unless meta

          created_at = Time.iso8601(meta["created_at"]) rescue nil
          next unless created_at && created_at < cutoff

          FileUtils.rm_rf(archive_dir(archive_id))
        end
      end

      def error(message)
        {"error" => message}
      end
    end
  end
end
