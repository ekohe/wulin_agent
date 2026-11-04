# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::DataStreamWriter do
  let(:output) { StringIO.new }
  let(:writer) { described_class.new(output) }

  def write_done
    writer.write(type: :done)
  end

  it "calls on_persist when the draft changes" do
    persisted = []
    writer = described_class.new(output, on_persist: ->(draft) { persisted << draft.assistant_text })

    writer.write(type: :text_delta, content: "Hello")
    writer.write(type: :text_delta, content: " world")

    expect(persisted).to eq(["Hello", "Hello world"])
  end

  it "encodes text deltas and finishes the stream" do
    writer.write(type: :text_delta, content: "Hello ")
    writer.write(type: :text_delta, content: "world")
    write_done

    expect(output.string).to include('0:"Hello "')
    expect(output.string).to include('0:"world"')
    expect(output.string).to include('d:{"finishReason":"stop"}')
    expect(output.string).to end_with("[DONE]\n")
    expect(writer.assistant_text).to eq("Hello world")
  end

  it "encodes tool calls and results" do
    writer.write(
      type: :tool_call,
      id: "call_1",
      name: "people__index",
      arguments: {"offset" => 0}
    )
    writer.write(
      type: :tool_result,
      id: "call_1",
      name: "people__index",
      result: {"total" => 2}
    )
    write_done

    expect(output.string).to include('"toolCallId":"call_1"')
    expect(output.string).to include('"toolName":"people__index"')
    expect(output.string).to include('"total":2')
  end

  it "includes the approval token and its expiry in streamed and stored tool results" do
    writer.write(
      type: :tool_result,
      id: "call_1",
      name: "people__destroy",
      result: {"status" => "approval_required"},
      approval_token: "tok-123",
      approval_expires_at: "2026-11-03T04:00:00Z"
    )
    write_done

    expect(output.string).to include('"approval_token":"tok-123"', '"approval_expires_at":"2026-11-03T04:00:00Z"')
    expect(writer.metadata["tool_results"].first["result"]).to include(
      "approval_token" => "tok-123", "approval_expires_at" => "2026-11-03T04:00:00Z"
    )
  end

  it "keeps the turn's text and tool calls in the order they happened" do
    writer.write(type: :text_delta, content: "Let me ")
    writer.write(type: :text_delta, content: "check.")
    writer.write(type: :tool_call, id: "call_1", name: "list_grids", arguments: {})
    writer.write(type: :tool_result, id: "call_1", name: "list_grids", result: [])
    writer.write(type: :tool_call, id: "call_2", name: "list_records", arguments: {"controller" => "people"})
    writer.write(type: :text_delta, content: "Found 2 people.")

    expect(writer.metadata["parts"]).to eq([
      {"type" => "text", "text" => "Let me check."},
      {"type" => "tool_call", "id" => "call_1"},
      {"type" => "tool_call", "id" => "call_2"},
      {"type" => "text", "text" => "Found 2 people."}
    ])
    expect(writer.assistant_text).to eq("Let me check.\n\nFound 2 people.")
  end

  it "writes a failure's message as a segment of its own" do
    writer.write(type: :text_delta, content: "Working on it.")
    writer.write(type: :error_text, content: "Error : boom")

    expect(writer.metadata["parts"].last).to eq("type" => "text", "text" => "Error : boom")
    expect(writer.assistant_text).to eq("Working on it.\n\nError : boom")
    expect(output.string).to include('3:"Error : boom"')
    expect(output.string).not_to include('0:"Error : boom"')
  end

  it "captures metadata for persistence" do
    writer.write(type: :text_delta, content: "Done.")
    writer.write(
      type: :tool_call,
      id: "call_1",
      name: "people__index",
      arguments: {"offset" => 0}
    )
    writer.write(
      type: :tool_result,
      id: "call_1",
      name: "people__index",
      result: {"total" => 2}
    )
    write_done

    expect(writer.metadata).to eq(
      "tool_calls" => [
        {"id" => "call_1", "name" => "people__index", "arguments" => {"offset" => 0}}
      ],
      "tool_results" => [
        {"id" => "call_1", "name" => "people__index", "result" => {"total" => 2}}
      ],
      "parts" => [
        {"type" => "text", "text" => "Done."},
        {"type" => "tool_call", "id" => "call_1"}
      ]
    )
  end
end
