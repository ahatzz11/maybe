require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include SyncableInterfaceTest, EntriesTestHelper

  setup do
    @account = @syncable = accounts(:depository)
    @family = families(:dylan_family)
  end

  test "can destroy" do
    assert_difference "Account.count", -1 do
      @account.destroy
    end
  end

  test "gets short/long subtype label" do
    account = @family.accounts.create!(
      name: "Test Investment",
      balance: 1000,
      currency: "USD",
      subtype: "hsa",
      accountable: Investment.new
    )

    assert_equal "HSA", account.short_subtype_label
    assert_equal "Health Savings Account", account.long_subtype_label

    # Test with nil subtype
    account.update!(subtype: nil)
    assert_equal "Investments", account.short_subtype_label
    assert_equal "Investments", account.long_subtype_label
  end

  test "ordered_by_position scope orders correctly with nils last" do
    family = families(:dylan_family) # Or create a new one

    # Ensure no other accounts in this family interfere if using existing family
    # For more isolation, consider: family = Family.create!(name: "Order Test Family", currency: "USD")
    # family.accounts.destroy_all if family.accounts.any?

    acc_nil = family.accounts.create!(name: "Nil Position", balance: 100, currency: "USD", accountable: Depository.new, position: nil, created_at: Time.now - 4.days)
    acc1 = family.accounts.create!(name: "Position 1", balance: 100, currency: "USD", accountable: Depository.new, position: 1, created_at: Time.now - 3.days)
    acc0 = family.accounts.create!(name: "Position 0", balance: 100, currency: "USD", accountable: Depository.new, position: 0, created_at: Time.now - 2.days)
    acc2 = family.accounts.create!(name: "Position 2", balance: 100, currency: "USD", accountable: Depository.new, position: 2, created_at: Time.now - 1.day)

    ordered_accounts = family.accounts.ordered_by_position.to_a

    assert_equal [acc0, acc1, acc2, acc_nil], ordered_accounts, "Accounts should be ordered by position (0, 1, 2), with nil last."
  end

  test "set_default_position callback: first account in a family gets position 0" do
    new_family = Family.create!(name: "New Family For Position Test", currency: "USD")
    first_account = new_family.accounts.create!(name: "First Account", balance: 100, currency: "USD", accountable: Depository.new)

    assert_equal 0, first_account.position, "First account in a new family should have position 0."
  end

  test "set_default_position callback: new account gets max position + 1" do
    family = families(:another_family) # Using a different family for isolation
    family.accounts.create!(name: "Existing Pos 0", balance: 100, currency: "USD", accountable: Depository.new, position: 0)
    family.accounts.create!(name: "Existing Pos 1", balance: 100, currency: "USD", accountable: Depository.new, position: 1)

    new_account = family.accounts.create!(name: "New Account", balance: 100, currency: "USD", accountable: Depository.new)

    assert_equal 2, new_account.position, "New account should get max existing position + 1."
  end

  test "set_default_position callback: multiple new accounts get sequential positions" do
    family = Family.create!(name: "Sequential Position Test Family", currency: "USD")

    acc1 = family.accounts.create!(name: "Seq Acc 1", balance: 100, currency: "USD", accountable: Depository.new)
    assert_equal 0, acc1.position, "First sequential account should have position 0."

    acc2 = family.accounts.create!(name: "Seq Acc 2", balance: 100, currency: "USD", accountable: Depository.new)
    assert_equal 1, acc2.position, "Second sequential account should have position 1."

    acc3 = family.accounts.create!(name: "Seq Acc 3", balance: 100, currency: "USD", accountable: Depository.new)
    assert_equal 2, acc3.position, "Third sequential account should have position 2."
  end

  test "set_default_position callback: new account in family with nil and non-nil positions" do
    family = Family.create!(name: "Mixed Position Test Family", currency: "USD")
    family.accounts.create!(name: "Nil Pos Account", balance: 100, currency: "USD", accountable: Depository.new, position: nil)
    family.accounts.create!(name: "Existing Pos 0 Account", balance: 100, currency: "USD", accountable: Depository.new, position: 0)

    new_account = family.accounts.create!(name: "New Mixed Account", balance: 100, currency: "USD", accountable: Depository.new)

    # Max position is 0, so next should be 1
    assert_equal 1, new_account.position, "New account should get max existing non-nil position + 1."

    another_new_account = family.accounts.create!(name: "Another New Mixed Account", balance: 100, currency: "USD", accountable: Depository.new)
    assert_equal 2, another_new_account.position, "Next new account should also increment from max non-nil position."
  end

  test "fixture-loaded accounts for dylan_family have non-nil and unique positions after migration" do
    # This test assumes the AddPositionToAccounts migration has run and backfilled positions.
    # The dylan_family is used as it has multiple accounts defined in fixtures.
    family = families(:dylan_family)
    
    # Reload accounts to ensure we get them directly from the DB state post-migration.
    # The order here doesn't strictly matter for this test, only that positions exist and are unique.
    accounts_for_family = family.accounts.reload 

    assert_not_empty accounts_for_family, "No accounts found for families(:dylan_family). Check fixtures."
    
    # There are 10 accounts for dylan_family in the provided fixtures.
    # The backfill would assign positions 0 through 9.
    expected_number_of_accounts = 10 
    assert_equal expected_number_of_accounts, accounts_for_family.size, 
                  "Expected #{expected_number_of_accounts} accounts for dylan_family, found #{accounts_for_family.size}. Update test if fixtures change."

    positions = []
    accounts_for_family.each do |account|
      assert_not_nil account.position, "Account '#{account.name}' (ID: #{account.id}) for dylan_family has a nil position. Migration backfill might have issues."
      positions << account.position
    end

    # Check for uniqueness of positions within this family
    assert_equal positions.uniq.size, positions.size, 
                  "Positions for accounts in dylan_family are not unique. Migration backfill might have issues. Positions found: #{positions.sort.inspect}"

    # Optional: Check if positions are within the expected range (0 to N-1)
    # This assumes the backfill logic (order by created_at, id then assign 0-indexed position)
    # has worked as expected on the fixture data.
    # The exact order of fixture loading can influence created_at/id, so the specific positions
    # assigned to specific named accounts aren't tested, just their presence, uniqueness, and range.
    assert_equal expected_number_of_accounts, positions.uniq.size, "There should be #{expected_number_of_accounts} unique positions."
    assert positions.all? { |p| p >= 0 && p < expected_number_of_accounts }, 
           "All positions should be within the range 0 to #{expected_number_of_accounts - 1}. Positions found: #{positions.sort.inspect}"
  end
end
