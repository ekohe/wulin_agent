# frozen_string_literal: true

require "spec_helper"
require "json"

# Hosts bundle app/javascript/wulin_agent.esm.js with wulin_master's esbuild
# command, which sets no JSX options and marks CSS imports external.
RSpec.describe "Frontend conventions" do
  root = File.expand_path("..", __dir__)

  it "selects the automatic JSX runtime in jsconfig.json, which esbuild reads for the gem's files" do
    config = JSON.parse(File.read(File.join(root, "jsconfig.json")))

    expect(config.dig("compilerOptions", "jsx")).to eq("react-jsx")
  end

  it "imports no CSS from JavaScript; the stylesheet reaches hosts through Sass" do
    importing = Dir[File.join(root, "app/javascript/**/*.{js,jsx}")].select do |file|
      File.read(file).match?(/^import\s+["'][^"']+\.css["']/)
    end

    expect(importing.map { |f| f.delete_prefix("#{root}/") }).to be_empty
    expect(File).to exist(File.join(root, "app/assets/stylesheets/wulin_agent.css"))
  end

  it "ships the esbuild entry hosts import" do
    expect(File).to exist(File.join(root, "app/javascript/wulin_agent.esm.js"))
  end
end
