# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Agent page", type: :request do
  before { User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", admin: true) }

  it "renders inside the host layout, menu included" do
    get "/wulin_agent"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("wulin-agent-page")
    expect(response.body).to include("People")
  end
end
