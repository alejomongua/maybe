class CreateRecurringTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :recurring_transactions, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, index: true, type: :uuid
      t.references :account, null: false, foreign_key: true, index: true, type: :uuid
      t.references :counter_account, null: true, foreign_key: { to_table: :accounts }, index: true, type: :uuid

      t.integer :kind, null: false, default: 0
      t.string :name, null: false
      t.text :notes
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.string :currency, null: false
      t.references :category, null: true, foreign_key: true, index: true, type: :uuid
      t.references :merchant, null: true, foreign_key: true, index: true, type: :uuid

      t.integer :day_of_month, null: false
      t.integer :interval_months, null: false, default: 1
      t.integer :weekend_strategy, null: false, default: 0

      t.date :start_on, null: false
      t.date :end_on
      t.date :next_run_on, null: false
      t.date :last_run_on
      t.string :timezone, null: false

      t.integer :status, null: false, default: 0
      t.references :created_by, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :recurring_transactions, [:family_id, :status, :next_run_on], name: "index_rt_on_family_status_next_run"
    add_index :recurring_transactions, :kind

    # Optional partial index for active + scheduled (Postgres)
    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE INDEX IF NOT EXISTS index_rt_on_next_run_active
          ON recurring_transactions (next_run_on)
          WHERE status = 0 AND next_run_on IS NOT NULL;
        SQL
      end
      dir.down do
        execute "DROP INDEX IF EXISTS index_rt_on_next_run_active;"
      end
    end
  end
end