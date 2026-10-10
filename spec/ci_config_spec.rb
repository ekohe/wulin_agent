# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe "CI configuration" do
  let(:ci) { YAML.load_file(File.expand_path("../.gitlab-ci.yml", __dir__)) }
  let(:before_script) { ci.fetch("before_script") }

  it "builds the dummy app's assets once the gems are installed" do
    build = before_script.index("spec/dummy/bin/build-assets")

    expect(build).not_to be_nil
    expect(build).to be > before_script.index("bundle check || bundle install --jobs 8")
    expect(File.executable?(File.expand_path("dummy/bin/build-assets", __dir__))).to be(true)
  end

  it "installs psql, which loads the dummy app's structure.sql" do
    install = before_script.find { |command| command.start_with?("apt-get install") }

    expect(install).to include("postgresql-client")
  end

  it "installs Node 22 before building assets" do
    node = before_script.index { |command| command.include?("deb.nodesource.com/node_22.x") }

    expect(node).not_to be_nil
    expect(node).to be < before_script.index("spec/dummy/bin/build-assets")
  end

  it "lints with standardrb, whose config leaves out vendored code" do
    expect(ci.dig("standardrb", "script")).to eq(["bundle exec standardrb"])
    expect(YAML.load_file(File.expand_path("../.standard.yml", __dir__)).fetch("ignore"))
      .to include("vendor/**/*", "spec/dummy/vendor/**/*", "spec/dummy/node_modules/**/*")
  end
end
