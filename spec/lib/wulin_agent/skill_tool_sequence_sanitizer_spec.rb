# frozen_string_literal: true

require "spec_helper"
require "wulin_agent/skill_tool_sequence_sanitizer"

RSpec.describe WulinAgent::SkillToolSequenceSanitizer do
  describe ".sanitize_sequence" do
    it "strips bulky plan payloads from host provisioning tools" do
      steps = [
        {
          "tool" => "analyze_config_flow",
          "params" => {"plan" => {"theme_id" => 39, "prompts" => [{"prompt" => "x" * 500}]}}
        },
        {
          "tool" => "provision_prompt_config",
          "params" => {"plan" => {"labels" => []}, "dry_run" => true}
        },
        {
          "tool" => "provision_prompt_config",
          "params" => {"plan" => {"labels" => []}, "dry_run" => false}
        }
      ]

      expect(described_class.sanitize_sequence(steps)).to eq(
        [
          {"tool" => "analyze_config_flow", "params" => {}},
          {"tool" => "provision_prompt_config", "params" => {"dry_run" => true}},
          {"tool" => "provision_prompt_config", "params" => {"dry_run" => false}}
        ]
      )
    end

    it "keeps grid structure but drops domain-specific filter values" do
      steps = [
        {
          "tool" => "list_records",
          "params" => {
            "controller" => "themes",
            "count" => 50,
            "sort_col" => "name",
            "sort_dir" => "ASC",
            "filters" => [{"column" => "name", "operator" => "include", "value" => "Semiconductor"}]
          }
        }
      ]

      expect(described_class.sanitize_sequence(steps)).to eq(
        [
          {
            "tool" => "list_records",
            "params" => {
              "controller" => "themes",
              "count" => 50,
              "sort_col" => "name",
              "sort_dir" => "ASC",
              "filters" => [{"column" => "name", "operator" => "include"}]
            }
          }
        ]
      )
    end

    it "removes consecutive duplicate sanitized steps" do
      steps = [
        {"tool" => "analyze_config_flow", "params" => {"plan" => {"theme_id" => 1}}},
        {"tool" => "analyze_config_flow", "params" => {"plan" => {"theme_id" => 2}}}
      ]

      expect(described_class.sanitize_sequence(steps)).to eq(
        [{"tool" => "analyze_config_flow", "params" => {}}]
      )
    end
  end
end
