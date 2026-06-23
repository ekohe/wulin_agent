# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent::Knowledge do
  describe "validations" do
    it "requires key, value, and a valid category" do
      entry = described_class.new

      expect(entry).not_to be_valid
      expect(entry.errors[:key]).to be_present
      expect(entry.errors[:value]).to be_present
      expect(entry.errors[:category]).to be_present
    end

    it "accepts all categories" do
      described_class::CATEGORIES.each do |category|
        entry = described_class.new(key: "K#{category}", value: "v", category: category)
        expect(entry).to be_valid
      end
    end

    it "enforces unique key within the same scope" do
      described_class.create!(key: "NHK", value: "first", category: "schema", scope: "orders")
      duplicate = described_class.new(key: "NHK", value: "second", category: "schema", scope: "orders")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to be_present
    end

    it "allows the same key in different scopes" do
      described_class.create!(key: "NHK", value: "orders", category: "schema", scope: "orders")
      other = described_class.new(key: "NHK", value: "global", category: "glossary")

      expect(other).to be_valid
    end
  end

  describe ".upsert_entry" do
    it "creates a new entry" do
      entry = described_class.upsert_entry(
        key: "MRL",
        value: "Media Rights Licensee",
        category: "acronym"
      )

      expect(entry).to be_persisted
      expect(entry.key).to eq("MRL")
    end

    it "updates an existing entry with the same key and scope" do
      described_class.create!(key: "MP", value: "old", category: "acronym")

      entry = described_class.upsert_entry(
        key: "MP",
        value: "Media Partner",
        category: "acronym"
      )

      expect(entry.value).to eq("Media Partner")
      expect(described_class.count).to eq(1)
    end
  end

  describe ".for_scope" do
    it "returns global and scoped entries for a given scope" do
      global = described_class.create!(key: "MRL", value: "global", category: "acronym")
      scoped = described_class.create!(key: "NHK", value: "orders", category: "schema", scope: "orders")
      described_class.create!(key: "SAD", value: "other", category: "acronym", scope: "people")

      expect(described_class.for_scope("orders")).to contain_exactly(global, scoped)
    end
  end

  describe "#global?" do
    it "is true when scope is blank" do
      expect(described_class.new(scope: nil).global?).to be(true)
      expect(described_class.new(scope: "orders").global?).to be(false)
    end
  end
end
