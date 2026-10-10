# frozen_string_literal: true

class PeopleController < WulinMaster::ScreenController
  controller_for_screen PersonScreen

  def greet
    name = params[:name].to_s.presence || "world"
    render json: {success: true, message: "Hello, #{name}!"}
  end

  def tag
    ids = Array(params[:person_ids]).map(&:to_i)
    render json: {success: true, count: ids.size}
  end

  def noop
    render json: {success: true}
  end
end
