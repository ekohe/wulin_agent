# frozen_string_literal: true

module DummyGridsHelper
  # The dummy's screen and grid register with WulinMaster when their classes
  # load, and eager_load is off in test, so specs load them by name.
  def load_dummy_grids
    [PersonScreen, PersonGrid]
  end
end

RSpec.configure do |config|
  config.include DummyGridsHelper
end
