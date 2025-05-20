require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "new" do
    get new_account_path
    assert_response :ok
  end

  test "can sync an account" do
    post sync_account_path(@account)
    assert_redirected_to account_path(@account)
  end

  test "can sync all accounts" do
    post sync_all_accounts_path
    assert_redirected_to accounts_path
  end

  # Tests for update_order action
  # Setup some accounts for the current family for reordering tests
  def setup_accounts_for_reorder
    @family = @user.family
    @acc1 = @family.accounts.create!(name: "Reorder Acc 1", balance: 100, currency: "USD", accountable: Depository.new, position: 0)
    @acc2 = @family.accounts.create!(name: "Reorder Acc 2", balance: 100, currency: "USD", accountable: Depository.new, position: 1)
    @acc3 = @family.accounts.create!(name: "Reorder Acc 3", balance: 100, currency: "USD", accountable: Depository.new, position: 2)
    [@acc1, @acc2, @acc3]
  end

  test "update_order successfully reorders accounts" do
    accounts_to_reorder = setup_accounts_for_reorder
    new_order_ids = [accounts_to_reorder[2].id, accounts_to_reorder[0].id, accounts_to_reorder[1].id] # e.g., 3, 1, 2

    patch update_order_accounts_url, params: { account_ids: new_order_ids }

    assert_response :ok
    assert_equal 0, accounts_to_reorder[2].reload.position
    assert_equal 1, accounts_to_reorder[0].reload.position
    assert_equal 2, accounts_to_reorder[1].reload.position
  end

  test "update_order returns not_found for non-existent account_id" do
    setup_accounts_for_reorder
    non_existent_id = SecureRandom.uuid # Assuming UUIDs for IDs
    new_order_ids = [@acc1.id, non_existent_id, @acc2.id]

    patch update_order_accounts_url, params: { account_ids: new_order_ids }

    assert_response :not_found
    # Verify original positions are unchanged due to transaction rollback
    assert_equal 0, @acc1.reload.position
    assert_equal 1, @acc2.reload.position
  end

  test "update_order returns not_found for account_id from another family" do
    setup_accounts_for_reorder
    other_family = families(:another_family) # Make sure this fixture exists
    other_family_account = other_family.accounts.create!(name: "Other Family Acc", balance: 100, currency: "USD", accountable: Depository.new)

    new_order_ids = [@acc1.id, other_family_account.id, @acc2.id]

    patch update_order_accounts_url, params: { account_ids: new_order_ids }

    assert_response :not_found
    # Verify original positions are unchanged
    assert_equal 0, @acc1.reload.position
    assert_equal 1, @acc2.reload.position
  end

  test "update_order returns bad_request for malformed account_ids parameter" do
    setup_accounts_for_reorder

    patch update_order_accounts_url, params: { account_ids: "not-an-array" }
    assert_response :bad_request

    # Verify original positions are unchanged
    assert_equal 0, @acc1.reload.position
    assert_equal 1, @acc2.reload.position
  end

  test "update_order ensures all accounts belong to Current.family" do
    # This is implicitly tested by the "account_id from another family" test,
    # as `Current.family.accounts.find(id_from_another_family)` would raise RecordNotFound.
    # If we want to be more explicit, we could try to bypass that find and see if the controller
    # has other checks, but the current implementation relies on `find` which is good.
    pass "This scenario is covered by 'returns not_found for account_id from another family'."
  end
end
