class AddPositionToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :position, :integer, null: true

    reversible do |dir|
      dir.up do
        # Backfill existing accounts
        # Ensure Account model is available for the migration
        # If not, define a minimal version here or require the model explicitly.
        # For this example, we assume the Account model is accessible.
        unless defined?(Account)
          # Minimal Account class definition if needed
          class Account < ActiveRecord::Base
            belongs_to :family
          end
        end
        
        unless defined?(Family)
          # Minimal Family class definition if needed
          class Family < ActiveRecord::Base
            has_many :accounts
          end
        end

        Family.find_each do |family|
          family.accounts.order(created_at: :asc, id: :asc).each_with_index do |account, index|
            account.update_column(:position, index)
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
