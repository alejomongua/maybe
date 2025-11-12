class AddUniqueIndexToTransactionsExternalId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    return unless column_exists?(:transactions, :external_id)

    unless index_exists?(:transactions, :external_id, unique: true, where: "external_id IS NOT NULL")
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