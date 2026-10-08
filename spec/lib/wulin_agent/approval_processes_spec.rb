# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "Approval grants across Ruby processes" do
  self.use_transactional_tests = false

  it "shares durable grants and allows exactly one concurrent consumer" do
    user = User.create!(email: "approval-#{SecureRandom.uuid}@example.com", admin: true)
    token = WulinAgent::Approvals.issue!(tool: "list_grids", params: {}, user_id: user.id)
    script = <<~RUBY
      grant = WulinAgent::Approvals.consume!(ENV.fetch("TEST_APPROVAL_TOKEN"), user_id: ENV.fetch("TEST_APPROVAL_USER"))
      puts(grant ? "claimed" : "missing")
    RUBY
    env = {"RAILS_ENV" => "test", "TEST_APPROVAL_TOKEN" => token, "TEST_APPROVAL_USER" => user.id.to_s}
    results = 2.times.map do
      Thread.new do
        Open3.capture3(env, RbConfig.ruby, "-r", Rails.root.join("config/environment").to_s,
          "-e", script, chdir: WulinAgent::Engine.root)
      end
    end.map(&:value)

    results.each { |_stdout, stderr, status| expect(status.success?).to be(true), stderr }
    expect(results.map { |stdout, _stderr, _status| stdout.lines.last.strip }).to contain_exactly("claimed", "missing")
  ensure
    WulinAgent::ApprovalGrant.where(user_id: user.id).delete_all if user
    user&.delete
  end
end
