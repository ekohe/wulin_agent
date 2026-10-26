# frozen_string_literal: true

require "ruby_llm"
require "wulin_agent/tool_adapter"
require "wulin_agent/tool_registry"

module WulinAgent
  class Runner
    MAX_CONTEXT_MESSAGES = 20

    def initialize(user:, model: nil, approval_mode: :confirm_writes, history: [])
      @user = user
      @model = model
      @approval_mode = approval_mode
      @history = history
    end

    def run(message, archive_id: nil, &block)
      @on_event = block
      scope_messages_for_completion!
      payload = ArchiveService.enrich_message(message, archive_id: archive_id, user: @user)
      response = chat.ask(payload) { |chunk| emit_text_delta(chunk) }
      emit(type: :done)
      response.is_a?(RubyLLM::Tool::Halt) ? "" : response.content
    ensure
      @on_event = nil
    end

    def run_approved(token:, params: nil, &block)
      @on_event = block
      grant = Approvals.consume!(token, user_id: @user.id)
      raise ArgumentError, "invalid approval token" unless grant

      spec = ToolRegistry.find(grant[:tool], @user)
      raise ArgumentError, "tool not found" unless spec

      raw = params || grant[:params] || {}
      raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      final_params = raw.deep_stringify_keys
      result = spec.execute(
        final_params,
        @user,
        approval_mode: @approval_mode,
        approved: true
      )

      emit(type: :tool_result, id: grant[:tool_call_id], name: grant[:tool], result: result)

      replace_tool_result!(grant[:tool_call_id], result)
      response = continue_agent_turn
      emit(type: :done)
      response
    ensure
      @on_event = nil
    end

    def run_rejected(token:, reason: nil, &block)
      @on_event = block
      grant = Approvals.consume!(token, user_id: @user.id)
      raise ArgumentError, "invalid approval token" unless grant
    
      message = reason.presence || "User declined #{grant[:tool]}"
      replace_tool_result!(
        grant[:tool_call_id],
        Approvals.rejection_result(tool: grant[:tool], reason: message)
      )

      response = continue_agent_turn
      emit(type: :done)
      response
    ensure
      @on_event = nil
    end

    def tools
      @tools ||= ToolAdapter.build(
        ToolRegistry.for(@user),
        user: @user,
        approval_mode: @approval_mode
      )
    end

    def messages
      chat.messages
    end

    def reset!
      @chat = nil
      @tools = nil
    end

    private

    def chat
      @chat ||= build_chat
    end

    def build_chat
      Rails.logger.info("[wulin_agent] model=#{resolved_model}")

      chat = RubyLLM.chat(model: resolved_model)
      chat = apply_llm_options(chat)
      chat = chat
        .with_tools(*tools, calls: :one)
        .with_instructions(system_prompt)
        .on_tool_call { |tc| emit_tool_call(tc) }
        .on_tool_result { |result| emit_tool_result(result) }
      @history.each { |msg| replay_message!(chat, msg) }
      chat
    end

    def apply_llm_options(chat)
      config = WulinAgent.config
      chat = chat.with_temperature(config.temperature) unless config.temperature.nil?
      if config.thinking_effort.present?
        chat = chat.with_thinking(effort: config.thinking_effort)
      end
      chat
    end

    def resolved_model
      @model.presence || RubyLLM.config.default_model
    end

    def system_prompt
      [base_system_prompt, knowledge_prompt_section, skill_prompt_section].compact.join
    end

    def base_system_prompt
      <<~PROMPT.strip
        You are a Wulin Master assistant. Use the available tools to read and
        modify grid data.

        Workflow:
        - Use the domain acronyms below when present. For other terms, call
          knowledge_search before querying grids.
        - Call list_grids to discover tables.
        - Call get_columns before create, update, or filtering.
        - Use controller names exactly as returned by list_grids.
        - Call only ONE tool at a time. Never request multiple tool calls in a
          single turn: issue one tool call, wait for its result, then decide the
          next one. This is required for write actions (create, update, delete)
          that need user approval, even when the user asks for several at once.

        User approval:
        - Write tools may pause for user approval before running.
        - If a tool result has status "rejected", the user declined that action.
          Do not retry that tool or call other tools. Reply in text only and
          briefly acknowledge what was not done.

        To search or filter records, call list_records with a filters array.
        Each filter needs column (from get_columns, must be filterable), value,
        and optionally operator: equals (exact on numbers/ids; text prefix only),
        starts_with (text prefix), include or contains (substring), not_equals, exclude,
        gte/lte/gt/lt (numeric columns only), between (value_from and value_to, numeric only).
        Date/datetime ranges are not supported — use sort_col and pagination.
        Combine multiple filters to narrow results. Use sort_col and sort_dir to order.
        When listing many records, pass fields with only the columns you need for triage
        (get_columns lists every column; host defaults may omit some from list_records until
        you name them in fields). Pass omit_columns: [] to list all columns. Use read_record
        with id or ids for full row detail (one or more records).

        To show a chart or visualization: first fetch rows with list_records, aggregate
        or count them YOURSELF, then call render_chart with the computed data array
        (each point: {label, value}, plus optional series for grouped/multi charts).
        Choose bar for comparisons, line for trends over time, pie for proportions.
        Never call render_chart with numbers you have not fetched. After the chart,
        optionally add a one-line text summary.

        Don't return charts in the chat, these are automatically shown by the tool result.

        To analyze attached text files: the user may attach a .zip archive or a
        single text file (.md, .csv, .html, etc.). The file contents are included
        directly in the user message. Use that content to answer; do not guess.

        Prefer tools over guessing. Be concise.

        Your responses are rendered as Markdown.
      PROMPT
    end

    def knowledge_prompt_section
      return unless defined?(WulinAgent::Knowledge)

      lines = WulinAgent::Knowledge.for_prompt.map { |key, value| "- #{key}: #{value}" }
      return if lines.empty?

      "\n\nDomain acronyms:\n#{lines.join("\n")}"
    end

    def skill_prompt_section
      return unless defined?(WulinAgent::Skill)
    
      lines = WulinAgent::Skill.for_prompt.map { |name, desc| "- #{name}: #{desc}" }
      return if lines.empty?
    
      "\n\nAvailable skills (call skill_read to load instructions):\n#{lines.join("\n")}"
    end

    def scope_messages_for_completion!
      if chat.respond_to?(:with_messages)
        chat.with_messages { |msgs| limited_messages(msgs) }
      else
        chat.instance_variable_set(:@messages, limited_messages(chat.messages))
      end
    end

    def continue_agent_turn
      scope_messages_for_completion!
      response = chat.complete { |chunk| emit_text_delta(chunk) }
      response.is_a?(RubyLLM::Tool::Halt) ? "" : response.content
    end

    def replay_message!(chat, msg)
      tool_calls = msg.dig(:metadata, "tool_calls") || []
      tool_results = msg.dig(:metadata, "tool_results") || []
      completed_ids = tool_results.map { |result| result["id"] }.to_set
      completed_calls = tool_calls.select { |call| completed_ids.include?(call["id"]) }

      if completed_calls.any?
        replay_assistant_tool_turn!(chat, msg[:content], completed_calls, tool_results)
        return
      end

      return if msg[:content].blank? && msg.dig(:metadata, "archive_id").blank?

      content =
        if msg[:role].to_s == "user" && msg.dig(:metadata, "archive_id").present?
          ArchiveService.enrich_message(
            msg[:content],
            archive_id: msg.dig(:metadata, "archive_id"),
            user: @user
          )
        else
          msg[:content]
        end

      chat.add_message(role: msg[:role], content: content)
    end

    def replay_assistant_tool_turn!(chat, content, tool_calls, tool_results)
      calls = tool_calls.index_by { |call| call["id"] }.transform_values do |call|
        RubyLLM::ToolCall.new(
          id: call["id"],
          name: call["name"],
          arguments: call["arguments"] || {}
        )
      end

      chat.add_message(role: :assistant, content: content.presence || "", tool_calls: calls)

      tool_calls.each do |call|
        tool_result = tool_results.find { |result| result["id"] == call["id"] }
        next unless tool_result

        chat.add_message(
          role: :tool,
          content: tool_result["result"].to_json,
          tool_call_id: call["id"]
        )
      end
    end

    def replace_tool_result!(tool_call_id, result)
      message = chat.messages.find { |msg| msg.tool_result? && msg.tool_call_id == tool_call_id }
      if message
        message.content = result
      else
        chat.add_message(role: :tool, content: result.to_json, tool_call_id: tool_call_id)
      end
    end

    def limited_messages(messages)
      system, rest = messages.partition { |msg| msg.role == :system }
      trimmed = rest.last(MAX_CONTEXT_MESSAGES)
      trimmed.shift while trimmed.first&.tool_result?
      system + trimmed
    end

    def emit(event)
      @on_event&.call(event)
    end

    def emit_tool_call(tool_call)
      @current_tool_call = tool_call
      emit(type: :tool_call, id: tool_call.id, name: tool_call.name, arguments: tool_call.arguments)
    end
    
    def emit_tool_result(result)
      result = result.content if result.is_a?(RubyLLM::Tool::Halt)

      payload = {
        type: :tool_result,
        id: @current_tool_call&.id,
        name: @current_tool_call&.name,
        result: result
      }
      if result.is_a?(Hash) && result["status"] == "approval_required"
        params = result["params"].presence || @current_tool_call&.arguments || {}
        params = params.stringify_keys
        result = result.merge("params" => params)
        payload[:result] = result
        payload[:approval_token] = Approvals.issue!(
          tool: result["tool"],
          params: params,
          user_id: @user.id,
          tool_call_id: @current_tool_call&.id
        )
      end
      emit(payload)
      @current_tool_call = nil
    end

    def emit_text_delta(chunk)
      content = chunk.content
      return if content.nil? || content.to_s.empty?
    
      emit(type: :text_delta, content: content.to_s)
    end
  end
end
