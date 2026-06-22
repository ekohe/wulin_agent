namespace :wulin_agent do
  desc "Scan custom grid actions for agent tool coverage"
  task scan: :environment do
    WulinAgent::ActionScanner.run(write: ENV["WRITE"].present?)
  end
end