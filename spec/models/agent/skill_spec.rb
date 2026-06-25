# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent::Skill do
  describe "validations" do
    it "requires name, description, and instructions" do
      skill = described_class.new

      expect(skill).not_to be_valid
      expect(skill.errors[:name]).to be_present
      expect(skill.errors[:description]).to be_present
      expect(skill.errors[:instructions]).to be_present
    end

    it "enforces a unique name (case-insensitive)" do
      described_class.create!(name: "attach_seats", description: "d", instructions: "i")
      duplicate = described_class.new(name: "ATTACH_SEATS", description: "d2", instructions: "i2")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end
  end

  describe ".for_prompt" do
    it "returns name and description ordered by name" do
      described_class.create!(name: "zebra", description: "last", instructions: "i")
      described_class.create!(name: "alpha", description: "first", instructions: "i")

      expect(described_class.for_prompt).to eq([["alpha", "first"], ["zebra", "last"]])
    end

    it "respects the limit" do
      35.times { |i| described_class.create!(name: "skill_#{i}", description: "d", instructions: "i") }

      expect(described_class.for_prompt(limit: 5).size).to eq(5)
    end
  end
end
