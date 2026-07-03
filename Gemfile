# frozen_string_literal: true

source "http://rubygems.org"

# Specify your gem's dependencies in wulin_agent.gemspec
gemspec

# Dev/test only — host apps declare wulin_master (and optionally wulin_permits) themselves.
gem "wulin_master", git: "git@gitlab.ekohe.com:ekohe/wulin/wulin_master.git", branch: "develop"
gem "wulin_permits", git: "git@gitlab.ekohe.com:ekohe/wulin/wulin_permits.git", branch: "develop"

gem "puma", "~> 8.0", group: :development
