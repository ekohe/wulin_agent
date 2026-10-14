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
      paused = pause_for_approval!
      emit(type: :done)
      paused ? "" : response.content
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
      Rails.logger.info("[wulin_agent] model=#{resolved_model} provider=#{WulinAgent.provider || "direct"}")

      chat = RubyLLM.chat(**WulinAgent.chat_options(resolved_model))
      chat = apply_llm_options(chat)
      chat = chat
        .with_tools(*tools)
        .with_tool_options(calls: :one)
        .with_instructions(system_prompt)
        .before_tool_call { |tc| emit_tool_call(tc) }
        .after_tool_result { |result| emit_tool_result(result) }
      @history.each { |msg| replay_message!(chat, msg) }
      chat
    end

    # ruby_llm sends both options as set. A model the registry says cannot
    # take one would fail every turn, so leave it out and say why; a model the
    # registry does not describe gets the option as configured.
    def apply_llm_options(chat)
      config = WulinAgent.config
      model = chat.model

      unless config.temperature.nil?
        if model.metadata[:temperature] == false
          Rails.logger.warn("[wulin_agent] #{model.id} does not take temperature; not sent")
        else
          chat = chat.with_temperature(config.temperature)
        end
      end

      if (effort = config.thinking_effort.presence)
        efforts = model.reasoning_option_values(:effort)
        if efforts.any? && !efforts.include?(effort.to_s)
          Rails.logger.warn("[wulin_agent] #{model.id} takes thinking effort #{efforts.join("/")}, not #{effort}; not sent")
        else
          chat = chat.with_thinking(effort: effort)
        end
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
        and optionally operator (equals, not_equals, include, exclude).
        For text columns, equals matches values starting with the given prefix.
        Combine multiple filters to narrow results. Use sort_col and sort_dir to order.

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
      chat.messages = limited_messages(chat.messages)
    end

    def continue_agent_turn
      scope_messages_for_completion!
      response = chat.complete { |chunk| emit_text_delta(chunk) }
      pause_for_approval! ? "" : response.content
    end

    # ruby_llm stops before running a tool that requires approval. The call is
    # reported like any other, with the approval_required result its ToolSpec
    # returns unapproved; emit_tool_result attaches the ApprovalGrant token and
    # the turn ends there. Returns whether the turn paused.
    def pause_for_approval!
      pending = chat.awaiting_approval? ? chat.pending_approvals : []
      pending.each do |tool_call|
        emit_tool_call(tool_call)
        spec = ToolRegistry.find(tool_call.name, @user)
        emit_tool_result(spec.execute(tool_call.arguments.to_h.stringify_keys, @user, approval_mode: @approval_mode))
      end
      pending.any?
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

    # Messages are immutable in ruby_llm 2, so the placeholder result is swapped
    # for a new message rather than edited.
    def replace_tool_result!(tool_call_id, result)
      replacement = RubyLLM::Message.new(role: :tool, content: result.to_json, tool_call_id: tool_call_id)
      index = chat.messages.index { |msg| msg.tool_result? && msg.tool_call_id == tool_call_id }
      if index
        messages = chat.messages.dup
        messages[index] = replacement
        chat.messages = messages
      else
        chat.add_message(replacement)
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
