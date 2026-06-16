# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::DataStreamWriter do
  let(:output) { StringIO.new }
  let(:writer) { described_class.new(output) }

  def write_done
    writer.write(type: :done)
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

  it "includes approval_token in streamed tool results" do
    writer.write(
      type: :tool_result,
      id: "call_1",
      name: "people__destroy",
      result: {"status" => "approval_required"},
      approval_token: "tok-123"
    )
    write_done

    expect(output.string).to include("approval_token")
    expect(output.string).to include("tok-123")
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
      ]
    )
  end
end
