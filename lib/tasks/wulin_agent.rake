namespace :wulin_agent do
  desc "Scan custom grid actions for agent tool coverage"
  task scan: :environment do
    WulinAgent::ActionScanner.run(write: ENV["WRITE"].present?)
  end

  namespace :token do
    desc "Create a token: rake 'wulin_agent:token:create[user@example.com,Cursor]'"
    task :create, [:email, :name] => :environment do |_t, args|
      user = User.find_by!(email: args[:email])
      token = WulinAgent::ApiToken.create!(user: user, name: args[:name])
      puts "Token (copy now, shown once): #{token.token}"
    end

    desc "List tokens: rake 'wulin_agent:token:list[user@example.com]'"
    task :list, [:email] => :environment do |_t, args|
      scope = args[:email] ? WulinAgent::ApiToken.joins(:user).where(users: {email: args[:email]}) : WulinAgent::ApiToken.all
      scope.find_each do |t|
        state = t.active? ? "active" : "revoked/expired"
        puts "##{t.id} #{t.name} (#{state}) last_used=#{t.last_used_at || "never"}"
      end
    end

    desc "Revoke a token by id: rake 'wulin_agent:token:revoke[12]'"
    task :revoke, [:id] => :environment do |_t, args|
      WulinAgent::ApiToken.find(args[:id]).revoke!
      puts "Revoked ##{args[:id]}"
    end
  end
end
