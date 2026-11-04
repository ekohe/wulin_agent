# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe WulinAgent::Engine do
  let(:append_migrations) do
    described_class.initializers.find { |i| i.name == :append_migrations }.bind(described_class.instance)
  end
  let(:engine_migrations) { described_class.root.join("db/migrate").to_s }

  def host_at(dir)
    Struct.new(:root, :config).new(Pathname(dir), Struct.new(:paths).new({"db/migrate" => []}))
  end

  it "appends its migrations to a host, like every wulin component" do
    Dir.mktmpdir do |dir|
      host = host_at(dir)
      append_migrations.run(host)

      expect(host.config.paths["db/migrate"]).to eq([engine_migrations])
    end
  end

  it "leaves alone a host that copied them with install:migrations" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/db/migrate")
      FileUtils.touch("#{dir}/db/migrate/20260701000000_create_agent_conversations.wulin_agent_engine.rb")
      host = host_at(dir)
      append_migrations.run(host)

      expect(host.config.paths["db/migrate"]).to be_empty
    end
  end
end
