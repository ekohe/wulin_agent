# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::SchemaFormatter do
  describe ".format" do
    it "formats a string param" do
      schema = {properties: {name: {type: "string"}}, required: []}

      expect(described_class.format(schema)).to eq("name: string")
    end

    it "formats a required array of integers" do
      schema = {
        properties: {person_ids: {type: "array", items: {type: "integer"}}},
        required: [:person_ids]
      }

      expect(described_class.format(schema)).to eq("person_ids: array<integer> (required)")
    end

    it "returns (no params) for an empty schema" do
      expect(described_class.format({properties: {}, required: []})).to eq("(no params)")
    end
  end
end
