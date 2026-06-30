# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::KnowledgeTools do
  let(:admin) { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  def find_tool(name)
    described_class.build.find { |tool| tool.name == name }
  end

  describe "knowledge_search" do
    let(:tool) { find_tool("knowledge_search") }

    before do
      WulinAgent::Knowledge.create!(key: "NHK", value: "Customer — Nippon Hoso Kyokai", category: "schema", scope: "orders")
      WulinAgent::Knowledge.create!(key: "MRL", value: "Media Rights Licensee", category: "acronym")
      WulinAgent::Knowledge.create!(key: "SAD", value: "Service Access Device", category: "acronym", scope: "people")
    end

    it "is not mutating" do
      expect(tool.mutating).to be(false)
    end

    it "finds entries by query" do
      result = tool.execute({"query" => "NHK"}, admin)

      expect(result).to contain_exactly(
        "key" => "NHK",
        "value" => "Customer — Nippon Hoso Kyokai",
        "category" => "schema",
        "scope" => "orders"
      )
    end

    it "filters by category" do
      result = tool.execute({"category" => "acronym"}, admin)

      expect(result.map { |entry| entry["key"] }).to contain_exactly("MRL", "SAD")
    end

    it "filters by scope including global entries" do
      result = tool.execute({"scope" => "orders"}, admin)

      expect(result.map { |entry| entry["key"] }).to contain_exactly("NHK", "MRL")
    end

    it "returns all entries when no filters are given" do
      result = tool.execute({}, admin)

      expect(result.size).to eq(3)
    end
  end

  describe "knowledge_upsert" do
    let(:tool) { find_tool("knowledge_upsert") }

    it "is mutating" do
      expect(tool.mutating).to be(true)
    end

    it "creates a new entry when approved" do
      result = tool.execute(
        {"key" => "MP", "value" => "Media Partner", "category" => "acronym"},
        admin,
        approved: true
      )

      expect(result).to eq(
        "key" => "MP",
        "value" => "Media Partner",
        "category" => "acronym",
        "scope" => nil
      )
    end

    it "updates an existing entry when approved" do
      WulinAgent::Knowledge.create!(key: "MP", value: "old", category: "acronym")

      result = tool.execute(
        {"key" => "MP", "value" => "Media Partner", "category" => "acronym"},
        admin,
        approved: true
      )

      expect(result["value"]).to eq("Media Partner")
      expect(WulinAgent::Knowledge.count).to eq(1)
    end

    it "requires approval under confirm_writes" do
      result = tool.execute(
        {"key" => "MP", "value" => "Media Partner", "category" => "acronym"},
        admin
      )

      expect(result["status"]).to eq("approval_required")
      expect(result["tool"]).to eq("knowledge_upsert")
    end

    it "returns an error for invalid categories" do
      result = tool.execute(
        {"key" => "X", "value" => "bad", "category" => "invalid"},
        admin,
        approved: true
      )

      expect(result["error"]).to be_present
    end
  end

  describe "knowledge_delete" do
    let(:tool) { find_tool("knowledge_delete") }

    before do
      WulinAgent::Knowledge.create!(key: "MP", value: "Media Partner", category: "acronym")
    end

    it "is mutating" do
      expect(tool.mutating).to be(true)
    end

    it "deletes an entry when approved" do
      result = tool.execute({"key" => "MP"}, admin, approved: true)

      expect(result).to eq("deleted" => "MP", "scope" => nil)
      expect(WulinAgent::Knowledge.find_by(key: "MP")).to be_nil
    end

    it "returns an error when the entry is missing" do
      result = tool.execute({"key" => "missing"}, admin, approved: true)

      expect(result).to eq("error" => "entry not found")
    end

    it "requires approval under confirm_writes" do
      result = tool.execute({"key" => "MP"}, admin)

      expect(result["status"]).to eq("approval_required")
    end
  end
end
