require "application_system_test_case"

class AccountsTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)

    Family.any_instance.stubs(:get_link_token).returns("test-link-token")

    visit root_url
    open_new_account_modal
  end

  test "can create depository account" do
    assert_account_created("Depository")
  end

  test "can create investment account" do
    assert_account_created("Investment")
  end

  test "can create crypto account" do
    assert_account_created("Crypto")
  end

  test "can create property account" do
    assert_account_created "Property" do
      fill_in "Year built", with: 2005
      fill_in "Living area", with: 2250
      fill_in "Street address", with: "123 Main St"
      fill_in "City", with: "San Francisco"
      fill_in "State/Province", with: "CA"
      fill_in "ZIP/Postal code", with: "94101"
      fill_in "Country", with: "US"
    end
  end

  test "can create vehicle account" do
    assert_account_created "Vehicle" do
      fill_in "Make", with: "Toyota"
      fill_in "Model", with: "Camry"
      fill_in "Year", with: "2020"
      fill_in "Mileage", with: "30000"
    end
  end

  test "can create other asset account" do
    assert_account_created("OtherAsset")
  end

  test "can create credit card account" do
    assert_account_created "CreditCard" do
      fill_in "Available credit", with: 1000
      fill_in "account[accountable_attributes][minimum_payment]", with: 25.51
      fill_in "APR", with: 15.25
      fill_in "Expiration date", with: 1.year.from_now.to_date
      fill_in "Annual fee", with: 100
    end
  end

  test "can create loan account" do
    assert_account_created "Loan" do
      fill_in "account[accountable_attributes][initial_balance]", with: 1000
      fill_in "Interest rate", with: 5.25
      select "Fixed", from: "Rate type"
      fill_in "Term (months)", with: 360
    end
  end

  test "can create other liability account" do
    assert_account_created("OtherLiability")
  end

  private

    def open_new_account_modal
      within "[data-controller='tabs']" do
        click_button "All"
        click_link "New account"
      end
    end

    def assert_account_created(accountable_type, &block)
      click_link Accountable.from_type(accountable_type).display_name.singularize
      click_link "Enter account balance" if accountable_type.in?(%w[Depository Investment Crypto Loan CreditCard])

      account_name = "[system test] #{accountable_type} Account"

      fill_in "Account name*", with: account_name
      fill_in "account[balance]", with: 100.99

      yield if block_given?

      click_button "Create Account"

      within_testid("account-sidebar-tabs") do
        click_on "All"
        find("details", text: Accountable.from_type(accountable_type).display_name).click
        assert_text account_name
      end

      visit accounts_url
      assert_text account_name

      created_account = Account.order(:created_at).last

      visit account_url(created_account)

      within_testid("account-menu") do
        find("button").click
        click_on "Edit"
      end

      fill_in "Account name", with: "Updated account name"
      click_button "Update Account"
      assert_selector "h2", text: "Updated account name"
    end

    def humanized_accountable(accountable_type)
      Accountable.from_type(accountable_type).display_name.singularize
    end

  # --- Tests for Account Reordering and Default Position ---

  def setup_accounts_for_system_reorder_test
    @family = @user.family
    # Ensure a clean slate or be mindful of existing accounts from fixtures if any
    # @family.accounts.destroy_all # Uncomment if needed for full isolation

    # Create accounts with specific initial positions for predictable testing
    # Note: Depository is used here as a simple default accountable type.
    # The actual accountable_type might influence which group they appear in.
    # For simplicity, assuming they all fall into a group that's easy to find.
    @sys_acc1 = @family.accounts.create!(name: "System Reorder Acc 1", balance: 100, currency: "USD", accountable: Depository.new, position: 0)
    @sys_acc2 = @family.accounts.create!(name: "System Reorder Acc 2", balance: 100, currency: "USD", accountable: Depository.new, position: 1)
    @sys_acc3 = @family.accounts.create!(name: "System Reorder Acc 3", balance: 100, currency: "USD", accountable: Depository.new, position: 2)

    # Ensure these accounts are part of the "Depository" group for the sidebar selector
    unless @sys_acc1.accountable_type == "Depository" && @sys_acc2.accountable_type == "Depository" && @sys_acc3.accountable_type == "Depository"
      raise "Test setup error: Accounts must be of Depository type for the current sidebar group selector."
    end
  end

  test "accounts in sidebar can be reordered via drag and drop" do
    setup_accounts_for_system_reorder_test
    visit root_path # Or any page where the sidebar is visible and accounts are listed

    # Wait for sidebar and accounts to be loaded
    # The specific group (e.g., "Depositories") needs to be open.
    # Let's assume "Depositories" is the group for these test accounts.
    # The `_accountable_group.html.erb` has a DisclosureComponent.
    # It might be closed by default. We need to ensure it's open to find the accounts.
    # Click the summary of the disclosure for "Depositories" if it's not open.
    # The `assert_account_created` implies accounts are grouped by type, e.g., "Depositories".
    # The testid "account-sidebar-tabs" is used. Let's find the group and click it.
    within_testid("account-sidebar-tabs") do
      # Click on the "Depositories" group summary to open it.
      # The text might be "Depositories" or similar based on Accountable.from_type("Depository").display_name
      # This assumes the disclosure component for "Depositories" contains the accounts.
      find("details summary", text: "Depositories").click
    end

    # Define the new order of account IDs
    new_order_ids = [@sys_acc3.id, @sys_acc1.id, @sys_acc2.id].map(&:to_s)

    # Locate the drag-sort container for the "Depositories" group.
    # The `_accountable_group.html.erb` applies data-controller="drag-sort" to a div.
    # We need to make sure we select the correct container if there are multiple such groups.
    # Let's assume the container is identifiable, e.g., by a class or an ID related to the group.
    # For now, we'll find the first one, assuming only one group is being tested for reorder.
    # A more specific selector would be: find("div[data-controller='drag-sort']", within: find("details", text: "Depositories"))
    drag_sort_container_selector = "div[data-controller='drag-sort'][data-drag-sort-url-value='/accounts/update_order']"
    
    # Ensure the specific container for "Depositories" is targeted.
    # The `account_groups` method in `BalanceSheet` creates groups based on `accountable_type`.
    # The key for Depository would be `depository`.
    # The `DisclosureComponent` might have an ID or data attribute we can use.
    # For now, let's assume the first `drag-sort` container is the one for Depositories,
    # or that the `find` below correctly targets it if the "Depositories" details element is the parent.
    depositories_group_details = find("details", text: "Depositories")
    drag_sort_container = depositories_group_details.find(drag_sort_container_selector)


    # JavaScript to reorder DOM elements and then trigger the Stimulus controller's action
    # This script assumes `application` is the global Stimulus application instance.
    # And that account IDs are strings.
    script = <<-JS
      const container = document.querySelector('#{drag_sort_container.path}'); // Use Capybara's resolved path for the container
      const controller = window.StimulusApp.getControllerForElementAndIdentifier(container, 'drag-sort');
      if (!controller) { throw new Error('DragSortController not found'); }
      if (!controller.sortable) { throw new Error('Sortable instance not found on controller'); }

      // New order of IDs
      const newOrderIds = #{new_order_ids.to_json};

      // Reorder the DOM elements manually
      // This is crucial because SortableJS's toArray() reads the current DOM order.
      const items = Array.from(container.children);
      const itemMap = new Map(items.map(item => [item.dataset.id, item]));
      
      newOrderIds.forEach(id => {
        const item = itemMap.get(id);
        if (item) container.appendChild(item); // Move item to the end in the new order
      });
      
      // Call the controller's onDragEnd method.
      // Pass a dummy event object if needed, though the current implementation doesn't use event properties.
      controller.onDragEnd({}); 
    JS

    execute_script(script)

    # Wait for the PATCH request to likely complete.
    # A more robust way would be to use Capybara's waiting assertions if the UI gives feedback.
    sleep 0.5 # Small wait for AJAX, replace with better waiting if possible

    # Verify positions in the database
    assert_equal 0, @sys_acc3.reload.position
    assert_equal 1, @sys_acc1.reload.position
    assert_equal 2, @sys_acc2.reload.position

    visit root_path # Refresh the page

    # Re-open the disclosure for "Depositories"
    within_testid("account-sidebar-tabs") do
      find("details summary", text: "Depositories").click
    end
    
    # Verify the new visual order in the sidebar
    # This assumes account names are unique enough for this assertion.
    # The accounts are inside links, inside the drag_sort_container.
    # We need to get the text of the links in their current DOM order.
    # The link text contains the account name.
    sidebar_account_names = depositories_group_details.all("div[data-controller='drag-sort'] a[data-id] > div > p.text-primary").map(&:text)
    
    expected_names_in_order = [@sys_acc3.name, @sys_acc1.name, @sys_acc2.name]
    assert_equal expected_names_in_order, sidebar_account_names
  end


  test "newly created account gets a default position and appears correctly in sidebar" do
    # Count existing accounts or find max position to predict next
    family = @user.family
    max_existing_position = family.accounts.maximum(:position)
    expected_new_position = max_existing_position.nil? ? 0 : max_existing_position + 1

    # Use parts of assert_account_created or create a new account manually via UI
    # For this test, let's focus on the position aspect.
    # We need to ensure the "Depositories" group is open when creating the new account.
    # The `assert_account_created` helper already navigates and creates.
    # It also opens the relevant group in the sidebar.

    # Re-using the setup from the class for `open_new_account_modal`
    # `visit root_url` and `open_new_account_modal` are in the main `setup`
    # So, the modal should be open here if we call `setup` or replicate its relevant parts.
    # For an isolated test, let's re-ensure the state:
    visit root_path
    open_new_account_modal
    
    accountable_type = "Depository" # Choose a type for the new account
    click_link Accountable.from_type(accountable_type).display_name.singularize
    click_link "Enter account balance" # Specific to Depository

    new_account_name = "[system test] New Positioned Account"
    fill_in "Account name*", with: new_account_name
    fill_in "account[balance]", with: 50.00
    click_button "Create Account"

    # Verify the account in the database
    newly_created_account = Account.find_by(name: new_account_name, family: family)
    assert_not_nil newly_created_account
    assert_equal expected_new_position, newly_created_account.position

    # Verify its visual position in the sidebar (should be last in its group if ordered by position)
    visit root_path # Refresh to ensure sidebar reflects DB state
    
    within_testid("account-sidebar-tabs") do
      find("details summary", text: "Depositories").click # Ensure the group is open
    end

    depositories_group_details = find("details", text: "Depositories")
    # Accounts are ordered by position (ASC NULLS LAST). New account should be last among positioned ones.
    # If all existing accounts had positions, this new one (e.g., pos 3) would be after pos 0, 1, 2.
    sidebar_account_elements = depositories_group_details.all("div[data-controller='drag-sort'] a[data-id]")
    
    # We expect the new account to be at the index corresponding to its position,
    # or last if there are accounts with nil positions.
    # Assuming all test accounts here have non-nil positions.
    
    # Get all account names in the current visual order
    # The `p.text-primary` selector targets the element containing the account name.
    current_sidebar_names = sidebar_account_elements.map { |el| el.find("div > p.text-primary").text }

    # Check if the new account is the last one in the list for its group.
    # This assumes that default_scope or other ordering doesn't interfere
    # and that `ordered_by_position` (ASC NULLS LAST) is correctly reflected.
    # The BalanceSheet model uses `ordered_by_position` for sorting accounts.
    assert_equal new_account_name, current_sidebar_names.last, "Newly created account should appear last in its group by position."
  end
end
