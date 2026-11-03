# frozen_string_literal: true

require "spec_helper"
require "json"

# Hosts bundle app/javascript/wulin_agent.esm.js with wulin_master's esbuild
# command, which sets no JSX options and marks CSS imports external.
RSpec.describe "Frontend conventions" do
  root = File.expand_path("..", __dir__)
  sources = Dir[File.join(root, "app/javascript/**/*.{js,jsx}")].to_h { |file| [file.delete_prefix("#{root}/"), File.read(file)] }

  it "selects the automatic JSX runtime in jsconfig.json, which esbuild reads for the gem's files" do
    config = JSON.parse(File.read(File.join(root, "jsconfig.json")))

    expect(config.dig("compilerOptions", "jsx")).to eq("react-jsx")
  end

  it "imports no CSS from JavaScript; the stylesheet reaches hosts through Sass" do
    importing = Dir[File.join(root, "app/javascript/**/*.{js,jsx}")].select do |file|
      File.read(file).match?(/^import\s+["'][^"']+\.css["']/)
    end

    expect(importing.map { |f| f.delete_prefix("#{root}/") }).to be_empty
    expect(File).to exist(File.join(root, "app/assets/stylesheets/wulin_agent.scss"))
  end

  # Colors themselves are checked on the compiled CSS in stylesheet_spec.rb.
  it "leaves colors to the stylesheet rather than reading them off the page" do
    sync = File.read(File.join(root, "app/javascript/wulin_agent/syncWulinTheme.js"))

    expect(sync).not_to include("--wulin-agent-main")
  end

  it "confirms through its own dialog, not the browser's or the host's" do
    expect(sources.select { |_, code| code.match?(/window\.confirm|displayCustomizedConfirmModal/) }.keys).to be_empty
  end

  it "ships the esbuild entry hosts import" do
    expect(File).to exist(File.join(root, "app/javascript/wulin_agent.esm.js"))
  end
end
