module WulinAgent
  module Extensions
    module GridAgentActions
      extend ActiveSupport::Concern

      included do
        class << self
          def agent_actions_pool
            @agent_actions_pool ||= []
          end
        end
      end

      class_methods do
        def agent_action(name, description: nil, params: {}, mutating: nil)
          agent_actions_pool << {
            name: name.to_sym,
            description: description,
            params: params,
            mutating: mutating
          }.compact
        end
      end
    end
  end
end
