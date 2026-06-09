# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent do
  it "has a version" do
    expect(WulinAgent::VERSION).to eq("0.1.0")
  end
end
