# frozen_string_literal: true

require "mcp"

module WulinAgent
  class McpController < ActionController::Base
    skip_forgery_protection
    before_action :authenticate_token!

    def handle
      status, headers, body = transport.handle_request(request)

      headers.each { |key, value| response.set_header(key, value) }

      if body.empty?
        head status
      else
        render json: body.first, status: status
      end
    end

    private

    def transport
      server = MCP::Server.new(
        name: "wulin_agent",
        version: WulinAgent::VERSION,
        tools: WulinAgent::McpAdapter.build(
          WulinAgent::ToolRegistry.for(current_user),
          user: current_user
        )
      )
      MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true)
    end

    def authenticate_token!
      return head :unauthorized unless api_token

      api_token.touch(:last_used_at)
    end

    def current_user
      @current_user ||= api_token&.user
    end

    def api_token
      return @api_token if defined?(@api_token)

      token = request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip
      @api_token = token.present? ? WulinAgent::ApiToken.active.find_by(token: token) : nil
    end
  end
end
