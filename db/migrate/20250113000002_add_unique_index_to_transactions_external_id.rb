class AddUniqueIndexToTransactionsExternalId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    return unless column_exists?(:transactions, :external_id)

    # Check if ANY index on external_id exists (not just unique with where clause)
    existing_indexes = ActiveRecord::Base.connection.indexes(:transactions)
    has_external_id_index = existing_indexes.any? { |idx| idx.columns.include?('external_id') }
    
    unless has_external_id_index
      add_index :transactions, :external_id, unique: true, algorithm: :concurrently, where: "external_id IS NOT NULL"
    end
  end

  def down
    return unless column_exists?(:transactions, :external_id)

    if index_exists?(:transactions, :external_id, unique: true, where: "external_id IS NOT NULL")
      remove_index :transactions, column: :external_id, algorithm: :concurrently
    end
  end
end