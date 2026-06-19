# frozen_string_literal: true

module WulinAgent
  class GridDispatcher
    class << self
      def call(controller, action, params = {}, user = nil)
        raise ArgumentError, "user is required" if user.nil? && defined?(WulinPermits)

        descriptor = Catalog.find(controller.to_s)
        controller_class = ControllerResolver.for_name(controller)
        return {"error" => "No controller resolved for #{controller}"} unless controller_class

        env = build_env(controller_class, descriptor&.grid_class, action, params.stringify_keys)
        response = dispatch(controller_class, action.to_s, env, user)
        parse_response(response)
      end

      def http_method_for(action)
        case action.to_s
        when "index", "show" then "GET"
        when "create" then "POST"
        when "update" then "PUT"
        when "destroy" then "DELETE"
        else "POST"
        end
      end

      def mutating?(action)
        http_method_for(action) != "GET"
      end

      private

      def build_env(controller_class, grid_class, action, params)
        controller_path = controller_class.controller_path
        request_params = params.merge(
          "controller" => controller_path,
          "action" => action.to_s,
          "format" => "json"
        )
        request_params["grid"] = grid_class.name if grid_class

        Rack::MockRequest.env_for(
          "/#{controller_path}.json",
          method: http_method_for(action),
          params: request_params
        )
      end

      def dispatch(controller_class, action, env, user = nil)
        request = ActionDispatch::Request.new(env)
        response = ActionDispatch::Response.new
        controller = controller_class.new
        controller.set_request!(request)
        controller.set_response!(response)
        controller.define_singleton_method(:current_user) { user } if user
        controller.process(action)
        response
      end

      def parse_response(response)
        body = response.body

        case response.status
        when 200..299
          JSON.parse(body)
        when 401
          {"error" => "unauthorized", "body" => JSON.parse(body)}
        else
          {"error" => response.status, "body" => body}
        end
      end
    end
  end
end
