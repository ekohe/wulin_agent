# frozen_string_literal: true

require "spec_helper"
require "wulin_agent/conversation_distiller"

RSpec.describe WulinAgent::ConversationDistiller do
  Msg = Struct.new(:metadata)

  it "keep successes and rejects others" do
    msg = Msg.new(
      "tool_calls" => [
        {"id" => "1", "name" => "list_records",   "arguments" => {"controller" => "people"}},
        {"id" => "2", "name" => "destroy_record", "arguments" => {"id" => 9}},
        {"id" => "3", "name" => "create_record",  "arguments" => {"controller" => "people"}}
      ],
      "tool_results" => [
        {"id" => "1", "result" => [{"id" => 1}]},            
        {"id" => "2", "result" => {"status" => "rejected"}}, 
        {"id" => "3", "result" => {"error" => "boom"}}
      ]
    )

    expect(described_class.steps_from(msg)).to eq([
      {"tool" => "list_records", "params" => {"controller" => "people"}}
    ])
  end
end