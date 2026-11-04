# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Host layout", type: :request do
  it "renders with the host's built assets" do
    get "/"

    expect(response).to have_http_status(:ok), lambda {
      "GET / returned #{response.status}. If spec/dummy/app/assets/builds is empty, " \
        "run spec/dummy/bin/build-assets before the specs."
    }
  end
end
