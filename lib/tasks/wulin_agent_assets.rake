# frozen_string_literal: true

namespace :wulin_agent do
  namespace :assets do
    desc "Install locked frontend dependencies and build Wulin Agent assets"
    task :build do
      app_path = WulinAgent::Engine.root.join("app").to_s
      Rake::FileUtilsExt.sh("npm", "ci", "--no-audit", "--no-fund", chdir: app_path)
      Rake::FileUtilsExt.sh("npm", "run", "build", chdir: app_path)
    end
  end
end

Rake::Task.define_task("assets:precompile" => "wulin_agent:assets:build")
