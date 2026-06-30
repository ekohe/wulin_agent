# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::ApiToken do
  let(:user) { User.create!(email: "user-#{SecureRandom.hex(4)}@example.com") }

  it "generates a token on creation" do
    expect(described_class.create!(user: user).token).to be_present
  end

  describe ".active" do
    it "includes a fresh token" do
      token = described_class.create!(user: user)

      expect(described_class.active).to include(token)
    end

    it "excludes a revoked token" do
      token = described_class.create!(user: user)
      token.revoke!

      expect(described_class.active).not_to include(token)
    end

    it "excludes an expired token" do
      token = described_class.create!(user: user, expires_at: 1.hour.ago)

      expect(described_class.active).not_to include(token)
    end

    it "includes a token expiring in the future" do
      token = described_class.create!(user: user, expires_at: 1.hour.from_now)

      expect(described_class.active).to include(token)
    end
  end

  describe "#revoke!" do
    it "marks the token as no longer active" do
      token = described_class.create!(user: user)

      expect { token.revoke! }.to change(token, :active?).from(true).to(false)
      expect(token.revoked_at).to be_present
    end
  end
end
