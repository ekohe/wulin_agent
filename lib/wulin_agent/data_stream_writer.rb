# frozen_string_literal: true

module WulinAgent
  class DataStreamWriter
    def initialize(stream, on_persist: nil)
      @stream = stream
      @on_persist = on_persist
      # The turn in the order it happened: text segments and the tool calls
      # between them. A turn makes one tool call per model round, so text
      # written before, between and after the calls is several segments.
      @parts = []
      @tool_calls = []
      @tool_results = []
      @closed = false
    end

    def write(event)
      case event[:type]
      when :text_delta then write_text_delta(event[:content])
      when :error_text then write_error_text(event[:content])
      when :tool_call then write_tool_call(event)
      when :tool_result then write_tool_result(event)
      when :done then close
      end
    end

    def close
      return if @closed

      write_line("d", {finishReason: "stop"}.to_json)
      @stream.write("[DONE]\n")
      flush
      @closed = true
    end

    def write_message_saved(id)
      write_line("8", {messageId: id}.to_json)
    end

    # Every text segment, a blank line apart so segments split by a tool call
    # stay separate paragraphs rather than running into each other.
    def assistant_text
      @parts.select { |part| part[:type] == "text" }.map { |part| part[:text] }.join("\n\n")
    end

    def metadata
      {
        "tool_calls" => @tool_calls.map(&:deep_stringify_keys),
        "tool_results" => @tool_results.map(&:deep_stringify_keys),
        "parts" => @parts.map(&:deep_stringify_keys)
      }
    end

    private

    def write_text_delta(content)
      text = content.to_s
      return if text.empty?

      last = @parts.last
      if last && last[:type] == "text"
        last[:text] += text
      else
        @parts << {type: "text", text: text}
      end
      write_line("0", text.to_json)
      persist!
    end

    # A failure's message is its own segment, after whatever the turn wrote,
    # and goes out as an error line so the client starts a segment for it too.
    def write_error_text(content)
      text = content.to_s
      return if text.empty?

      @parts << {type: "text", text: text}
      write_line("3", text.to_json)
      persist!
    end

    def write_tool_call(event)
      id = event[:id]
      name = event[:name]
      arguments = event[:arguments] || {}

      @tool_calls << {id: id, name: name, arguments: arguments}
      @parts << {type: "tool_call", id: id}

      write_line("b", {toolCallId: id, toolName: name}.to_json)
      write_line("c", arguments.to_json)
      persist!
    end

    def write_tool_result(event)
      result = (event[:result] || {}).dup
      result["approval_token"] = event[:approval_token] if event[:approval_token]
      result["approval_expires_at"] = event[:approval_expires_at] if event[:approval_expires_at]

      @tool_results << {id: event[:id], name: event[:name], result: result}

      write_line("a", {toolCallId: event[:id], result: result}.to_json)
      persist!
    end

    def persist!
      @on_persist&.call(self)
    end

    def write_line(prefix, payload)
      @stream.write("#{prefix}:#{payload}\n")
      flush
    end

    def flush
      @stream.flush if @stream.respond_to?(:flush)
    end
  end
end
