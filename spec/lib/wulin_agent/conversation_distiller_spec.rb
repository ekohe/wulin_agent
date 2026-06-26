# frozen_string_literal: true

require "spec_helper"
require "wulin_agent/conversation_distiller"

RSpec.describe WulinAgent::ConversationDistiller do
  def message(metadata)
    Struct.new(:metadata).new(metadata)
  end

  describe ".steps_from" do
    it "keeps successful steps and drops errors, rejections and approval-required" do
      msg = message(
        "tool_calls" => [
          {"id" => "1", "name" => "list_records",   "arguments" => {"controller" => "people"}},
          {"id" => "2", "name" => "destroy_record", "arguments" => {"id" => 9}},
          {"id" => "3", "name" => "create_record",  "arguments" => {"controller" => "people"}},
          {"id" => "4", "name" => "people__attach", "arguments" => {"id" => 1}}
        ],
        "tool_results" => [
          {"id" => "1", "result" => [{"id" => 1}]},
          {"id" => "2", "result" => {"status" => "rejected"}},
          {"id" => "3", "result" => {"error" => "boom"}},
          {"id" => "4", "result" => {"status" => "approval_required", "approval_token" => "t"}}
        ]
      )

      expect(described_class.steps_from(msg)).to eq(
        [{"tool" => "list_records", "params" => {"controller" => "people"}}]
      )
    end

    it "drops a call that has no matching result" do
      msg = message(
        "tool_calls" => [{"id" => "1", "name" => "list_records", "arguments" => {}}],
        "tool_results" => []
      )

      expect(described_class.steps_from(msg)).to eq([])
    end

    it "defaults params to an empty hash when arguments are missing" do
      msg = message(
        "tool_calls" => [{"id" => "1", "name" => "list_grids"}],
        "tool_results" => [{"id" => "1", "result" => [{"controller" => "people"}]}]
      )

      expect(described_class.steps_from(msg)).to eq([{"tool" => "list_grids", "params" => {}}])
    end

    it "returns an empty array when metadata has no tool calls" do
      expect(described_class.steps_from(message({}))).to eq([])
      expect(described_class.steps_from(message(nil))).to eq([])
    end
  end
end
