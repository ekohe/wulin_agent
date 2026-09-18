# frozen_string_literal: true

require "spec_helper"

RSpec.describe "wulin_agent migrations" do
  it "have unique version numbers" do
    versions = Dir[File.expand_path("../db/migrate/*.rb", __dir__)]
      .map { |path| File.basename(path).split("_").first }

    duplicates = versions.group_by(&:itself).select { |_, group| group.size > 1 }.keys
    expect(duplicates).to be_empty, "duplicate migration versions: #{duplicates.join(', ')}"
  end
end
