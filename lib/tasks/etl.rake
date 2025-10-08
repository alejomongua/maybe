# lib/tasks/etl.rake
require 'duckdb'

namespace :etl do
  desc 'Extract data from PostgreSQL and load it into DuckDB'
  task to_duckdb: :environment do
    puts 'Starting ETL process...'

    # 1. Set up DuckDB database
    db_path = Rails.root.join('db', 'production.duckdb')
    db = DuckDB::Database.open(db_path)
    con = db.connect

    puts "DuckDB database created/opened at: #{db_path}"

    # 2. Extract data from PostgreSQL
    puts 'Extracting data from PostgreSQL...'
    
    # Extract data from key tables
    @families = Family.all.to_a
    @accounts = Account.all.to_a
    @entries = Entry.all.to_a
    @transactions = Transaction.all.to_a
    @categories = Category.all.to_a
    @merchants = Merchant.all.to_a
    @holdings = Holding.all.to_a
    @securities = Security.all.to_a
    @balances = Balance.all.to_a
    
    puts "Extracted #{@families.size} families, #{@accounts.size} accounts, #{@entries.size} entries, #{@transactions.size} transactions, #{@categories.size} categories, #{@merchants.size} merchants, #{@holdings.size} holdings, #{@securities.size} securities, #{@balances.size} balances"

    # 3. Load data into DuckDB
    puts 'Loading data into DuckDB...'

    # Define type mapping from PostgreSQL to DuckDB
    type_mapping = {
      'uuid' => 'UUID',
      'string' => 'VARCHAR',
      'text' => 'VARCHAR',
      'integer' => 'BIGINT',
      'bigint' => 'BIGINT',
      'decimal' => 'DECIMAL(19,4)',
      'float' => 'DOUBLE',
      'boolean' => 'BOOLEAN',
      'date' => 'DATE',
      'datetime' => 'TIMESTAMP',
      'jsonb' => 'VARCHAR',
      'enum' => 'VARCHAR'
    }

    # Map of collections to their table names
    collections = {
      '@families' => 'families',
      '@accounts' => 'accounts',
      '@entries' => 'entries',
      '@transactions' => 'transactions',
      '@categories' => 'categories',
      '@merchants' => 'merchants',
      '@holdings' => 'holdings',
      '@securities' => 'securities',
      '@balances' => 'balances'
    }

    # Load each collection into DuckDB
    collections.each do |collection_var, table_name|
      records = instance_variable_get(collection_var)
      next if records.empty?

      puts "Loading #{records.size} records into #{table_name} table..."

      # Get the model class to determine column types
      model_class = table_name.singularize.classify.constantize
      
      # Create table with appropriate schema
      columns = model_class.columns.map do |col|
        duckdb_type = type_mapping[col.type.to_s] || 'VARCHAR'
        "#{col.name} #{duckdb_type}"
      end

      # Drop table if it exists and create new one
      con.execute("DROP TABLE IF EXISTS #{table_name}")
      con.execute("CREATE TABLE #{table_name} (#{columns.join(', ')})")

      # Use appender for efficient bulk insertion
      appender = con.appender(table_name)
      
      records.each do |record|
        # Prepare values for insertion, handling special types
        values = model_class.columns.map do |col|
          value = record.send(col.name)
          
          # Handle type conversions
          case col.type
          when :datetime, :date
            value&.iso8601
          when :jsonb
            value.to_json
          when :decimal
            value&.to_f
          else
            value
          end
        end
        
        appender.append_row(*values)
      end
      
      appender.flush
      appender.close

      puts "✓ Loaded #{records.size} records into #{table_name}"
    end

    puts 'ETL process finished.'
  end
end