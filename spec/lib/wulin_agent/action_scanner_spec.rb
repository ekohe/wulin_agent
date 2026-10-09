# frozen_string_literal: true

require "rails_helper"
require "stringio"

RSpec.describe WulinAgent::ActionScanner do
  let(:drafts_path) { Rails.root.join("config/wulin_agent_actions.rb") }

  before do
    WulinAgent::Catalog.reset!
    PersonScreen
    PersonGrid
  end

  after do
    FileUtils.rm_f(drafts_path)
  end

  describe ".run" do
    it "prints coverage for each custom action status" do
      output = capture_stdout { described_class.run }

      expect(output).to include("skip people__fullscreen")
      expect(output).to include("declared people__greet")
      expect(output).to include("inferred people__tag")
      expect(output).to include("partial  people__noop")
      # Engine grids (wulin_permits' users, roles, …) are scanned too.
      expect(output).to match(/Summary: 1 declared, \d+ inferred, 1 partial, 0 manual, \d+ skipped/)
    end

    it "writes draft agent_action declarations when write: true" do
      described_class.run(write: true)

      expect(drafts_path).to exist
      content = File.read(drafts_path)
      expect(content).to include("class PersonGrid")
      expect(content).to include("agent_action :noop")
      expect(content).to include('description: "Noop"')
    end

    it "does not write drafts by default" do
      described_class.run

      expect(drafts_path).not_to exist
    end
  end

  describe ".generate_drafts_file" do
    it "groups drafts by grid class" do
      grid = WulinAgent::Catalog.find("people")
      tool = WulinAgent::ActionInferer.build(grid).find { |t| t.name == "people__noop" }
      drafts = [{grid: grid, operation: "noop", status: :partial, tool: tool}]

      content = described_class.send(:generate_drafts_file, drafts)

      expect(content).to include("agent_action :noop")
      expect(content).to include('description: "Noop"')
    end
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
