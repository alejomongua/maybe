namespace :transactions do
  desc "Export transactions to CSV file"
  task :export, [:email, :filename, :start_date, :end_date, :account_id] => :environment do |t, args|
    # Default values
    args.with_defaults(
      filename: Rails.root.join("exports", "transactions_export_#{Date.current.strftime('%Y%m%d')}.csv").to_s
    )

    # Find user by email
    user = User.find_by(email: args[:email])
    unless user
      puts "Error: User with email '#{args[:email]}' not found"
      exit 1
    end

    # Set Current context
    session = Session.create!(user: user, user_agent: "RakeTask", ip_address: "127.0.0.1")
    Current.session = session

    # Build query
    transactions = Current.family.transactions
      .includes(:category, :tags, entry: :account)
      .joins(:entry)

    # Apply date filters
    if args[:start_date].present?
      start_date = Date.parse(args[:start_date])
      transactions = transactions.where("entries.date >= ?", start_date)
    end

    if args[:end_date].present?
      end_date = Date.parse(args[:end_date])
      transactions = transactions.where("entries.date <= ?", end_date)
    end

    # Apply account filter
    if args[:account_id].present?
      transactions = transactions.where(entries: { account_id: args[:account_id] })
    end

    # Sort by date descending
    transactions = transactions.order("entries.date DESC")

    # Generate CSV
    CSV.open(args[:filename], "wb") do |csv|
      # Headers
      csv << [
        "Date",
        "Account",
        "Amount",
        "Name",
        "Category",
        "Tags",
        "Notes",
        "Currency",
        "Excluded",
        "Type"
      ]

      # Data rows
      transactions.find_each do |transaction|
        csv << [
          transaction.entry.date.strftime("%Y-%m-%d"),
          transaction.entry.account.name,
          transaction.entry.amount.to_f,
          transaction.entry.name,
          transaction.category&.name,
          transaction.tags.pluck(:name).join(", "),
          transaction.entry.notes,
          transaction.entry.currency,
          transaction.entry.excluded ? "Yes" : "No",
          transaction.kind
        ]
      end
    end

    count = transactions.count
    puts "✅ Successfully exported #{count} transactions to #{args[:filename]}"
    puts "\nFilters applied:"
    puts "  User: #{user.email} (Family: #{Current.family.name})"
    puts "  Start date: #{args[:start_date] || 'Not specified'}"
    puts "  End date: #{args[:end_date] || 'Not specified'}"
    puts "  Account ID: #{args[:account_id] || 'All accounts'}"
  end

  desc "Export transactions with account balances"
  task :export_with_balances, [:email, :filename] => :environment do |t, args|
    args.with_defaults(
      filename: Rails.root.join("exports", "transactions_with_balances_#{Date.current.strftime('%Y%m%d')}.csv").to_s
    )

    user = User.find_by(email: args[:email])
    unless user
      puts "Error: User with email '#{args[:email]}' not found"
      exit 1
    end

    session = Session.create!(user: user, user_agent: "RakeTask", ip_address: "127.0.0.1")
    Current.session = session

    CSV.open(args[:filename], "wb") do |csv|
      csv << [
        "Date",
        "Account",
        "Amount",
        "Running Balance",
        "Name",
        "Category",
        "Tags",
        "Notes",
        "Currency"
      ]

      # Process by account for running balances
      Current.family.accounts.find_each do |account|
        running_balance = 0.0
        
        transactions = account.entries
          .transactions
          .includes(entryable: [:category, :tags])
          .order(date: :asc, created_at: :asc)

        transactions.each do |entry|
          transaction = entry.entryable
          running_balance += entry.amount.to_f

          csv << [
            entry.date.strftime("%Y-%m-%d"),
            account.name,
            entry.amount.to_f,
            running_balance,
            entry.name,
            transaction.category&.name,
            transaction.tags.pluck(:name).join(", "),
            entry.notes,
            entry.currency
          ]
        end
      end
    end

    puts "✅ Successfully exported transactions with running balances to #{args[:filename]}"
  end

  desc "List available accounts for export"
  task :list_accounts, [:email] => :environment do |t, args|
    user = User.find_by(email: args[:email])
    unless user
      puts "Error: User with email '#{args[:email]}' not found"
      exit 1
    end

    session = Session.create!(user: user, user_agent: "RakeTask", ip_address: "127.0.0.1")
    Current.session = session

    puts "\nAvailable accounts for #{user.email}:"
    puts "-" * 60
    puts "%-36s %-20s %s" % ["ID", "Name", "Type"]
    puts "-" * 60

    Current.family.accounts.order(:name).each do |account|
      puts "%-36s %-20s %s" % [account.id, account.name, account.accountable_type]
    end
  end
end

# Usage examples:
# 
# Basic export for a user:
#   rails transactions:export[user@example.com]
#
# Export with custom filename:
#   rails transactions:export[user@example.com,my_transactions.csv]
#
# Export with date range:
#   rails transactions:export[user@example.com,filtered.csv,2024-01-01,2024-12-31]
#
# Export for specific account:
#   rails transactions:export[user@example.com,checking.csv,,,account-uuid-here]
#
# Export with running balances:
#   rails transactions:export_with_balances[user@example.com]
#
# List available accounts:
#   rails transactions:list_accounts[user@example.com]