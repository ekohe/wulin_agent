# frozen_string_literal: true

# As written by wulin_master/templates/wulin_master.rb: esbuild bundles the
# javascript, dart-sass the stylesheet, Propshaft serves both.
Rails.application.configure do
  config.assets.paths << Rails.root.join("app/assets/builds")
  config.assets.paths << Rails.root.join("app/assets/fonts")
  config.assets.precompile += %w[*.woff *.woff2]

  # sassc-rails arrives with Sprockets and libsass cannot re-parse dart-sass output.
  config.assets.css_compressor = nil

  config.dartsass.builds = {"application.sass" => "application.css"}
  config.dartsass.build_options << "--load-path=node_modules"
  config.dartsass.build_options << "--load-path=app/assets/stylesheets"
  config.dartsass.build_options << "--load-path=vendor/gems/wulin_master/app/assets/stylesheets"
end
