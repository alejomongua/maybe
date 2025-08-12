namespace :balance do
  desc "Debug and recalculate balances for a user"
  task :recalculate, [:email] => :environment do |task, args|
    email = args[:email] || "alejom.tv@gmail.com"
    
    user = User.find_by(email: email)
    
    unless user
      puts "❌ User not found with email: #{email}"
      puts "Usage: rake balance:recalculate[user@example.com]"
      exit 1
    end
    
    puts "🔍 Processing user: #{email}"
    
    session = Session.create!(user: user, user_agent: "Debug", ip_address: "127.0.0.1")
    Current.session = session

    puts "User family: #{Current.family.name}"
    puts "Number of accounts: #{Current.family.accounts.count}"
    puts "First account balance: #{Current.family.accounts.first&.balance}"

    # Check net worth series
    net_worth_series = Current.family.balance_sheet.net_worth_series
    puts "Net worth series values count: #{net_worth_series.values.count}"
    puts "Current net worth from trend: #{net_worth_series.trend&.current}"
    puts "First value in series: #{net_worth_series.values.first&.value}"
    puts "Last value in series: #{net_worth_series.values.last&.value}"

    # Check individual account
    account = Current.family.accounts.first
    if account
      puts "\nAccount: #{account.name}"
      puts "Account balance: #{account.balance}"
      puts "Account balances count: #{account.balances.count}"
      puts "Latest balance record: #{account.balances.order(date: :desc).first&.inspect}"

      # Check balance series
      series = account.balance_series
      puts "Balance series values count: #{series.values.count}"
      puts "First value: #{series.values.first&.value}"
      puts "Last value: #{series.values.last&.value}"
    end

    # Check if there are any balance records at all
    puts "\nTotal balance records in family: #{Balance.joins(account: :family).where(accounts: { family_id: Current.family.id }).count}"

    # Recalculate balances for all accounts
    Current.family.accounts.find_each do |account|
      puts "Recalculating balances for: #{account.name}"

      # Clear existing balances
      account.balances.destroy_all

      # Trigger balance recalculation
      Balance::Materializer.new(account, strategy: :forward).materialize_balances

      puts "✅ Recalculated #{account.balances.count} balance records"
    end

    puts "\n🎉 Balance recalculation complete!"
  end
end