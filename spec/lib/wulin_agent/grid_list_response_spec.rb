# frozen_string_literal: true

require "rails_helper"
require "wulin_agent/grid_list_response"

RSpec.describe WulinAgent::GridListResponse do
  describe ".sanitize_metadata" do
    it "removes sql debug keys by default" do
      payload = {"total" => 1, "rows" => [], "sql" => "SELECT 1", "query" => "SELECT 1"}

      result = described_class.sanitize_metadata(payload)

      expect(result).to eq("total" => 1, "rows" => [])
    end

    it "keeps debug keys when debug is true" do
      payload = {"total" => 1, "rows" => [], "sql" => "SELECT 1"}

      result = described_class.sanitize_metadata(payload, debug: true)

      expect(result["sql"]).to eq("SELECT 1")
    end
  end
end
