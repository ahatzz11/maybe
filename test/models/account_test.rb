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
end
