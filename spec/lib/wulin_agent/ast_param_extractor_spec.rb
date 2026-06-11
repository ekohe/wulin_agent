# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::AstParamExtractor do
  describe "#to_schema" do
    it "infers greet params" do
      schema = described_class.new(PeopleController, :greet).to_schema

      expect(schema).to eq(
        properties: {name: {type: "string"}},
        required: []
      )
    end

    it "infers tag params as array of integers" do
      schema = described_class.new(PeopleController, :tag).to_schema

      expect(schema).to eq(
        properties: {person_ids: {type: "array", items: {type: "integer"}}},
        required: [:person_ids]
      )
    end
  end
end
