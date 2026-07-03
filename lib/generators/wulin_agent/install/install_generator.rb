# frozen_string_literal: true

module WulinAgent
  class InstallGenerator < Rails::Generators::Base
    desc "Install wulin_agent in the host application"

    source_root File.expand_path("templates", __dir__)

    def copy_initializer
      copy_file "wulin_agent.rb", "config/initializers/wulin_agent.rb"
    end

    def configure_assets
      link_wulin_agent_manifest
      require_wulin_agent_js
      require_wulin_agent_css
    end

    def add_layout_mount_point
      %w[haml erb].each do |ext|
        path = "app/views/layouts/application.html.#{ext}"
        next unless File.exist?(path)
        next if File.read(path).include?("wulin-agent-root")

        snippet = layout_mount_snippet(ext)
        inject_into_file path, before: /<\/body>/i do
          "\n#{snippet}\n"
        end
        say "Added #wulin-agent-root to #{path}", :green
        return
      end

      say "No host layout found — panel still mounts via JS on document.body", :yellow
    end

    def show_post_install
      say_status :info, "wulin_agent installed", :green
      say "  Routes: automatic with the gem (/wulin_agent/conversations)", :green
      say "  Next steps:", :yellow
      say "    rails db:migrate"
      say "    rake wulin_permits:load_permission"
      say "    export OPENAI_API_KEY=sk-..."
      say "    # optional: export WULIN_AGENT_MODEL=claude-sonnet-4-6"
    end

    private

    def layout_mount_snippet(ext)
      case ext
      when "haml"
        "  %div#wulin-agent-root"
      when "erb"
        '  <div id="wulin-agent-root"></div>'
      else
        raise ArgumentError, "unsupported layout extension: #{ext}"
      end
    end

    def link_wulin_agent_manifest
      path = "app/assets/config/manifest.js"
      unless File.exist?(path)
        say "Skipped #{path} (not found)", :yellow
        return
      end
      return if File.read(path).include?("wulin_agent")
      inject_into_file path, before: /\z/ do
        "//= link wulin_agent/manifest.js\n"
      end
    end

    def require_wulin_agent_js
      paths = [
        "app/assets/javascripts/application.js",
        "app/assets/javascript/application.js",
        "app/javascripts/application.js",
        "app/javascript/application.js"
      ]
      path = paths.find { |p| File.exist?(p) }
      unless path
        say "Skipped application.js (not found)", :yellow
        return
      end
      return if File.read(path).include?("wulin_agent")
      inject_into_file path, before: /\z/ do
        "//= require wulin_agent\n"
      end
    end

    def require_wulin_agent_css
      path = "app/assets/stylesheets/application.css"
      unless File.exist?(path)
        say "Skipped #{path} (not found)", :yellow
        return
      end
      content = File.read(path)
      return if content.include?("wulin_agent")

      if content.include?("*/")
        gsub_file path, /\s*\*\//, "\n *= require wulin_agent\n */"
      else
        inject_into_file path, before: /\z/ do
          "*= require wulin_agent\n"
        end
      end
    end
  end
end