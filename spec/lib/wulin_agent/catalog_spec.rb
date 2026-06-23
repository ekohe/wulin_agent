# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::Catalog do
  before do
    described_class.reset!
    PersonScreen
    PersonGrid
  end

  describe ".all" do
    it "rebuilds the registry when Grid.grids was cleared after load" do
      PersonGrid
      WulinMaster::Grid.grids.clear

      expect(described_class.all.map(&:controller)).to eq(["people"])
    end
  end

  describe ".find" do
    it "describes people grid columns, actions, and choices" do
      grid = described_class.find("people")

      expect(grid.controller).to eq("people")
      expect(grid.controller_class).to eq(PeopleController)
      expect(grid.screen_name).to eq("person")
      expect(grid.grid_class).to eq(PersonGrid)

      first_name = grid.columns.find { |c| c.name == :first_name }
      expect(first_name.label).to eq("First name")
      expect(first_name.sql_type).to eq(:string)
      expect(first_name.full_name).to eq("first_name")

      job = grid.columns.find { |c| c.name == :job }
      expect(job.choices).to eq(PersonGrid::JOBS)

      status = grid.columns.find { |c| c.name == :status }
      expect(status.sql_type).to eq(:enum)
      expect(status.choices).to eq(Person.statuses.keys)

      expect(grid.default_actions).to eq(
        "create" => true,
        "edit" => true,
        "delete" => true
      )

      expect(grid.custom_actions.map { |a| a[:name] }).to include(:fullscreen)
    end
  end
end
