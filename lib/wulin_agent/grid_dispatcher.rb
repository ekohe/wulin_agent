# frozen_string_literal: true

module WulinAgent
  class GridDispatcher
    class << self
      def call(controller, action, params = {}, user = nil)
        raise ArgumentError, "user is required" if user.nil? && defined?(WulinPermits)

        controller_class = resolve_controller(controller)
        env = build_env(controller, action, params.stringify_keys, user)
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

      def resolve_controller(name)
        "#{name.camelize}Controller".constantize
      end

      def build_env(controller, action, params, _user = nil)
        Rack::MockRequest.env_for(
          "/#{controller}.json",
          method: http_method_for(action),
          params: params.merge(
            "controller" => controller,
            "action" => action,
            "format" => "json"
          )
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
          { "error" => "unauthorized", "body" => JSON.parse(body) }
        else
          { "error" => response.status, "body" => body }
        end
      end
    end
  end
end