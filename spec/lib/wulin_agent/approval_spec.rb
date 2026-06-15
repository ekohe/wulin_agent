# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::Approval do
  let(:read_tool) { instance_double(WulinAgent::ToolSpec, mutating: false) }
  let(:write_tool) { instance_double(WulinAgent::ToolSpec, mutating: true) }

  describe ".needs_approval?" do
    it "skips approval when already approved" do
      expect(described_class.needs_approval?(write_tool, mode: :confirm_writes, approved: true)).to be(false)
    end

    it "skips approval in auto mode" do
      expect(described_class.needs_approval?(write_tool, mode: :auto)).to be(false)
    end

    it "requires approval for all tools in confirm_all mode" do
      expect(described_class.needs_approval?(read_tool, mode: :confirm_all)).to be(true)
    end

    it "requires approval only for mutating tools in confirm_writes mode" do
      expect(described_class.needs_approval?(read_tool, mode: :confirm_writes)).to be(false)
      expect(described_class.needs_approval?(write_tool, mode: :confirm_writes)).to be(true)
    end
  end
end
