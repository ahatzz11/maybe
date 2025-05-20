# Minimal temporary model definitions for the migration
module MigrationModels
  class Account < ActiveRecord::Base
    self.table_name = :accounts
    belongs_to :family, class_name: 'MigrationModels::Family', foreign_key: 'family_id'
  end

  class Family < ActiveRecord::Base
    self.table_name = :families
    has_many :accounts, -> { order(created_at: :asc, id: :asc) }, class_name: 'MigrationModels::Account', foreign_key: 'family_id'
  end
end

class AddPositionToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :position, :integer, null: true

    reversible do |dir|
      dir.up do
        # Backfill existing accounts using the models defined in MigrationModels module
        MigrationModels::Family.find_each do |family|
          family.accounts.each_with_index do |account, index|
            # Using update_column to skip validations and callbacks, which is common in migrations.
            # The Account model here is MigrationModels::Account.
            MigrationModels::Account.where(id: account.id).update_all(position: index)
          end
        end
      end

      dir.down do
        # The column will be removed by the reverse of add_column,
        # no need to revert position values specifically.
      end
    end
  end
end
