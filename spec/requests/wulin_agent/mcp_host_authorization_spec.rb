# frozen_string_literal: true

require "rails_helper"

# Through Rails' own HostAuthorization: the dummy's test environment sets no config.hosts, so the
# middleware is not in its stack, and is put in front of the app here as a host app with a list would.
RSpec.describe "MCP endpoint behind host authorization", type: :request do
  let(:hosts) { ["agent.example.com"] }
  let(:app) { ActionDispatch::HostAuthorization.new(Rails.application, hosts) }
  let(:token) { WulinAgent::ApiToken.create!(user: User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true)).token }

  before { allow(Rails.application.config).to receive(:hosts).and_return(hosts) }

  def list_tools(host)
    Rack::MockRequest.new(app).post(
      "/wulin_agent/mcp",
      "HTTP_HOST" => host,
      "HTTP_AUTHORIZATION" => "Bearer #{token}",
      "CONTENT_TYPE" => "application/json",
      "HTTP_ACCEPT" => "application/json, text/event-stream",
      :input => {jsonrpc: "2.0", id: 1, method: "tools/list"}.to_json
    )
  end

  it "answers on a host the list names" do
    response = list_tools("agent.example.com")

    expect(response.status).to eq(200)
    expect(JSON.parse(response.body).dig("result", "tools")).not_to be_empty
  end

  it "leaves a host the list does not name to Rails, which blocks it" do
    response = list_tools("untrusted.example.com")

    expect(response.status).to eq(403)
    expect(response.body).not_to include("Invalid Host header")
  end
end
