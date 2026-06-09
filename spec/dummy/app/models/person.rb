# frozen_string_literal: true

class Person < ApplicationRecord
  enum :status, %i[busy avaialbe free]

  def name
    first_name
  end
end
