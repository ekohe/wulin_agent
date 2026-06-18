# frozen_string_literal: true

module WulinAgent
  module Extensions
    module Layout
      extend ActiveSupport::Concern

      included do
        before_action :inject_wulin_agent_assets, unless: -> { request.xhr? }
      end

      private

      def inject_wulin_agent_assets
        view_context.content_for :header_tags do
          view_context.safe_join([
            view_context.stylesheet_link_tag("wulin_agent", media: "all"),
            view_context.javascript_include_tag("wulin_agent")
          ])
        end
      end
    end
  end
end
