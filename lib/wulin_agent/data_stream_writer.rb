# frozen_string_literal: true

module WulinAgent
  class DataStreamWriter
    def initialize(stream, on_persist: nil)
      @stream = stream
      @on_persist = on_persist
      @text_parts = []
      @tool_calls = []
      @tool_results = []
      @closed = false
    end

    def write(event)
      case event[:type]
      when :text_delta then write_text_delta(event[:content])
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

    def write_error(message)
      write_line("3", message.to_json)
      close
    end

    def write_message_saved(id)
      write_line("8", {messageId: id}.to_json)
    end

    def assistant_text
      @text_parts.join
    end

    def metadata
      {
        "tool_calls" => @tool_calls.map(&:deep_stringify_keys),
        "tool_results" => @tool_results.map(&:deep_stringify_keys)
      }
    end

    private

    def write_text_delta(content)
      text = content.to_s
      return if text.empty?

      @text_parts << text
      write_line("0", text.to_json)
      persist!
    end

    def write_tool_call(event)
      id = event[:id]
      name = event[:name]
      arguments = event[:arguments] || {}

      @tool_calls << {id: id, name: name, arguments: arguments}

      write_line("b", {toolCallId: id, toolName: name}.to_json)
      write_line("c", arguments.to_json)
      persist!
    end

    def write_tool_result(event)
      result = (event[:result] || {}).dup
      result["approval_token"] = event[:approval_token] if event[:approval_token]

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
