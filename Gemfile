# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in wulin_agent.gemspec
gemspec

# Dev/test only — host apps declare wulin_master (and optionally wulin_permits) themselves.
gem "wulin_master", github: "ekohe/wulin_master", branch: "v3"
gem "wulin_permits", github: "ekohe/wulin_permits", branch: "main"

# The dummy app's asset pipeline, matching wulin_master v3 hosts.
gem "propshaft"

gem "puma", "~> 8.0", group: :development
