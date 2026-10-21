# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::McpController, type: :controller do
  routes { Rails.application.routes }

  before do
    request.host = "localhost"
    WulinAgent::Catalog.reset!
    WulinAgent::ToolRegistry.reset!
    Permission.find_or_create_by!(name: "person#read")
    Permission.find_or_create_by!(name: "person#cud")
  end

  def rpc(method, params = {}, token: nil, id: 1)
    request.headers["Authorization"] = "Bearer #{token}" if token
    request.headers["Content-Type"] = "application/json"
    request.headers["Accept"] = "application/json, text/event-stream"

    payload = {jsonrpc: "2.0", id: id, method: method}
    payload[:params] = params unless params.empty?

    post :handle, body: payload.to_json
  end

  def tool_names(response)
    JSON.parse(response.body).dig("result", "tools").map { |tool| tool["name"] }
  end

  describe "host validation" do
    let(:token) { WulinAgent::ApiToken.create!(user: User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true)).token }

    it "keeps to loopback hosts when the app checks no hosts" do
      allow(Rails.application.config).to receive(:hosts).and_return([])
      request.host = "agent.example.com"

      rpc("tools/list", token: token)

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Invalid Host header")
    end

    it "keeps to loopback hosts when host authorization is switched off" do
      allow(Rails.application.config).to receive(:hosts).and_return(nil)
      request.host = "agent.example.com"

      rpc("tools/list", token: token)

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Invalid Host header")
    end

    it "accepts a hostname configured by the host application" do
      allow(WulinAgent.config).to receive(:mcp_allowed_hosts).and_return(["agent.example.com"])
      request.host = "agent.example.com"

      rpc("tools/list", token: token)

      expect(response).to have_http_status(:ok)
      expect(tool_names(response)).to include("list_grids")
    end

    it "rejects a hostname outside the configured hosts" do
      allow(WulinAgent.config).to receive(:mcp_allowed_hosts).and_return(["agent.example.com"])
      request.host = "untrusted.example.com"

      rpc("tools/list", token: token)

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Invalid Host header")
    end

    it "rejects a browser request from another site" do
      allow(Rails.application.config).to receive(:hosts).and_return(["agent.example.com"])
      request.host = "agent.example.com"
      request.headers["Origin"] = "https://evil.example.com"

      rpc("tools/list", token: token)

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Invalid Origin header")
    end
  end

  describe "authentication" do
    it "returns unauthorized without a token" do
      rpc("tools/list")

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized with an unknown token" do
      rpc("tools/list", token: "nope")

      expect(response).to have_http_status(:unauthorized)
    end

    it "records last_used_at on a successful request" do
      api_token = WulinAgent::ApiToken.create!(user: User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true))

      expect { rpc("tools/list", token: api_token.token) }
        .to change { api_token.reload.last_used_at }.from(nil)
    end

    it "returns unauthorized with a revoked token" do
      api_token = WulinAgent::ApiToken.create!(user: User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true))
      api_token.revoke!

      rpc("tools/list", token: api_token.token)

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns unauthorized with an expired token" do
      api_token = WulinAgent::ApiToken.create!(
        user: User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true),
        expires_at: 1.hour.ago
      )

      rpc("tools/list", token: api_token.token)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "tools/list" do
    it "lists every tool for an admin token" do
      admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true)
      token = WulinAgent::ApiToken.create!(user: admin).token

      rpc("tools/list", token: token)

      expect(response).to have_http_status(:ok)
      expect(tool_names(response)).to include(
        "list_grids", "list_records", "read_record",
        "create_record", "update_record", "destroy_record"
      )
    end

    it "hides mutating tools from a read-only token" do
      reader = create_user_with_permissions("person#read")
      token = WulinAgent::ApiToken.create!(user: reader).token

      rpc("tools/list", token: token)

      names = tool_names(response)
      expect(names).to include("list_records", "read_record")
      expect(names).not_to include("create_record", "update_record", "destroy_record")
    end
  end

  describe "tools/call" do
    it "executes a tool and returns its result" do
      admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true)
      token = WulinAgent::ApiToken.create!(user: admin).token

      rpc("tools/call", {name: "list_grids", arguments: {}}, token: token)

      expect(response).to have_http_status(:ok)
      content = JSON.parse(response.body).dig("result", "content")
      expect(content.first["type"]).to eq("text")
    end
  end
end
