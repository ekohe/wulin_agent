# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Host layout", type: :request do
  it "renders with the built agent bundle" do
    get "/"

    expect(response).to have_http_status(:ok), lambda {
      "GET / returned #{response.status}. If app/assets/builds is empty, " \
        "run `bin/rails wulin_agent:assets:build` before the specs."
    }
  end
end
