# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "open3"
require "tmpdir"
require "fileutils"

RSpec.describe "CI configuration" do
  let(:ci) { YAML.load_file(File.expand_path("../.gitlab-ci.yml", __dir__)) }

  it "fetches both private gems over HTTPS using the job token without saving credentials" do
    setup = ci.fetch("before_script").find { |command| command.include?("GIT_CONFIG_KEY_0") }
    expect(setup).not_to be_nil

    %w[wulin_master wulin_permits].each do |gem_name|
      env = {
        "CI_JOB_TOKEN" => "test-job-token",
        "CI_SERVER_HOST" => "gitlab.ekohe.com",
        "GIT_CONFIG_GLOBAL" => File::NULL,
        "GIT_CONFIG_NOSYSTEM" => "1"
      }
      output, error, status = Open3.capture3(env, "sh", "-ec", "#{setup}\ngit ls-remote --get-url git@gitlab.ekohe.com:ekohe/wulin/#{gem_name}.git")

      expect(status.success?).to be(true), error
      expect(output.strip).to eq("https://gitlab-ci-token:test-job-token@gitlab.ekohe.com/ekohe/wulin/#{gem_name}.git")
    end

    expect(setup).not_to include("--global", "--local")
    expect(ci.fetch("before_script").index(setup)).to be < ci.fetch("before_script").index("bundle check || bundle install --jobs 8")
  end

  it "builds the frontend from app/ and returns to the gem root for RSpec" do
    commands = ci.fetch("before_script").select { |command| command.include?("npm ci") }

    Dir.mktmpdir("wulin-agent-ci") do |directory|
      directory = File.realpath(directory)
      FileUtils.mkdir_p(["#{directory}/app", "#{directory}/bin"])
      npm = "#{directory}/bin/npm"
      File.write(npm, "#!/bin/sh\nprintf '%s:%s\\n' \"$PWD\" \"$*\" >> \"$CI_TEST_LOG\"\n")
      File.chmod(0o755, npm)
      log = "#{directory}/npm.log"
      env = {"PATH" => "#{directory}/bin:#{ENV.fetch("PATH")}", "CI_TEST_LOG" => log}

      output, error, status = Open3.capture3(env, "sh", "-ec", "#{commands.join("\n")}\npwd", chdir: directory)

      expect(status.success?).to be(true), error
      expect(File.readlines(log, chomp: true)).to eq([
        "#{directory}/app:ci",
        "#{directory}/app:run build"
      ])
      expect(output.strip).to eq(directory)
    end
  end
end
