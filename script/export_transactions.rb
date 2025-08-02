#!/usr/bin/env ruby

# Standalone script to export transactions to CSV
# Usage: ruby script/export_transactions.rb user@example.com [options]

require_relative "../config/environment"
require "optparse"
require "csv"

class TransactionExporter
  def initialize(email, options = {})
    @email = email
    @options = options
    @user = User.find_by(email: email)
    
    unless @user
      puts "Error: User with email '#{email}' not found"
      exit 1
    end

    Current.user = @user
    Current.family = @user.family
  end

  def export
    filename = @options[:filename] || "transactions_#{Date.current.strftime('%Y%m%d_%H%M%S')}.csv"
    
    transactions = build_query
    count = export_to_csv(transactions, filename)
    
    puts "\n✅ Successfully exported #{count} transactions to #{filename}"
    print_summary
  end

  def export_by_account
    filename_base = @options[:filename] || "transactions"
    timestamp = Date.current.strftime('%Y%m%d_%H%M%S')
    
    Current.family.accounts.each do |account|
      transactions = build_query.where(entries: { account_id: account.id })
      next if transactions.count.zero?

      filename = "#{filename_base}_#{account.name.parameterize}_#{timestamp}.csv"
      count = export_to_csv(transactions, filename)
      
      puts "✅ Exported #{count} transactions for #{account.name} to #{filename}"
    end
  end

  def export_summary
    filename = @options[:filename] || "transaction_summary_#{Date.current.strftime('%Y%m%d_%H%M%S')}.csv"
    
    # Group by category
    summary_data = Current.family.transactions
      .joins(:entry, :category)
      .group("categories.name")
      .sum("entries.amount")

    CSV.open(filename, "wb") do |csv|
      csv << ["Category", "Total Amount", "Transaction Count"]
      
      summary_data.each do |category_name, total|
        count = Current.family.transactions
          .joins(:entry, :category)
          .where(categories: { name: category_name })
          .count
          
        csv << [category_name, total.to_f, count]
      end
    end

    puts "✅ Exported transaction summary to #{filename}"
  end

  private

  def build_query
    transactions = Current.family.transactions
      .includes(:category, :tags, entry: :account)
      .joins(:entry)

    # Apply filters
    if @options[:start_date]
      transactions = transactions.where("entries.date >= ?", @options[:start_date])
    end

    if @options[:end_date]
      transactions = transactions.where("entries.date <= ?", @options[:end_date])
    end

    if @options[:account_id]
      transactions = transactions.where(entries: { account_id: @options[:account_id] })
    end

    if @options[:category]
      transactions = transactions.joins(:category).where("categories.name ILIKE ?", "%#{@options[:category]}%")
    end

    if @options[:min_amount]
      transactions = transactions.where("ABS(entries.amount) >= ?", @options[:min_amount].to_f)
    end

    # Sort
    sort_order = @options[:ascending] ? "ASC" : "DESC"
    transactions.order("entries.date #{sort_order}, entries.created_at #{sort_order}")
  end

  def export_to_csv(transactions, filename)
    CSV.open(filename, "wb") do |csv|
      csv << headers

      transactions.find_each do |transaction|
        csv << transaction_row(transaction)
      end
    end

    transactions.count
  end

  def headers
    headers = [
      "Date",
      "Account",
      "Amount",
      "Name",
      "Category",
      "Tags",
      "Notes",
      "Currency"
    ]

    headers << "Excluded" if @options[:include_excluded]
    headers << "Type" if @options[:include_type]
    headers << "ID" if @options[:include_id]

    headers
  end

  def transaction_row(transaction)
    row = [
      transaction.entry.date.strftime("%Y-%m-%d"),
      transaction.entry.account.name,
      transaction.entry.amount.to_f,
      transaction.entry.name,
      transaction.category&.name,
      transaction.tags.pluck(:name).join(", "),
      transaction.entry.notes,
      transaction.entry.currency
    ]

    row << (transaction.entry.excluded ? "Yes" : "No") if @options[:include_excluded]
    row << transaction.kind if @options[:include_type]
    row << transaction.id if @options[:include_id]

    row
  end

  def print_summary
    puts "\nExport Summary:"
    puts "  User: #{@user.email}"
    puts "  Family: #{Current.family.name}"
    puts "  Date range: #{@options[:start_date] || 'Beginning'} to #{@options[:end_date] || 'Today'}"
    puts "  Account: #{@options[:account_id] ? Account.find(@options[:account_id]).name : 'All accounts'}" if @options[:account_id]
    puts "  Category filter: #{@options[:category]}" if @options[:category]
    puts "  Min amount: #{@options[:min_amount]}" if @options[:min_amount]
  end
end

# Parse command line options
options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby script/export_transactions.rb EMAIL [options]"

  opts.on("-f", "--filename FILE", "Output filename") do |f|
    options[:filename] = f
  end

  opts.on("-s", "--start-date DATE", "Start date (YYYY-MM-DD)") do |d|
    options[:start_date] = Date.parse(d)
  end

  opts.on("-e", "--end-date DATE", "End date (YYYY-MM-DD)") do |d|
    options[:end_date] = Date.parse(d)
  end

  opts.on("-a", "--account ID", "Filter by account ID") do |id|
    options[:account_id] = id
  end

  opts.on("-c", "--category NAME", "Filter by category name (partial match)") do |name|
    options[:category] = name
  end

  opts.on("-m", "--min-amount AMOUNT", "Minimum transaction amount (absolute value)") do |amount|
    options[:min_amount] = amount.to_f
  end

  opts.on("--ascending", "Sort by date ascending (default: descending)") do
    options[:ascending] = true
  end

  opts.on("--include-excluded", "Include excluded transactions column") do
    options[:include_excluded] = true
  end

  opts.on("--include-type", "Include transaction type column") do
    options[:include_type] = true
  end

  opts.on("--include-id", "Include transaction ID column") do
    options[:include_id] = true
  end

  opts.on("--by-account", "Export separate file for each account") do
    options[:by_account] = true
  end

  opts.on("--summary", "Export category summary instead of transactions") do
    options[:summary] = true
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end

parser.parse!

# Check for required email argument
if ARGV.empty?
  puts parser
  exit 1
end

email = ARGV[0]
exporter = TransactionExporter.new(email, options)

# Execute based on mode
if options[:summary]
  exporter.export_summary
elsif options[:by_account]
  exporter.export_by_account
else
  exporter.export
end