# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinMaster::Grid do
  it "includes PersonGrid" do
    PersonGrid
    expect(described_class.grids).to include(PersonGrid)
  end
end
