class AccountsController < ApplicationController
  before_action :set_account, only: %i[sync chart sparkline]
  include Periodable

  def index
    @manual_accounts = family.accounts.manual.alphabetically
    @plaid_items = family.plaid_items.ordered

    render layout: "settings"
  end

  def sync
    unless @account.syncing?
      @account.sync_later
    end

    redirect_to account_path(@account)
  end

  def chart
    @chart_view = params[:chart_view] || "balance"
    render layout: "application"
  end

  def sparkline
    render layout: false
  end

  def sync_all
    unless family.syncing?
      family.sync_later
    end

    redirect_back_or_to accounts_path
  end

  def update_order
    account_ids = params[:account_ids]

    unless account_ids.is_a?(Array)
      return head :bad_request
    end

    ActiveRecord::Base.transaction do
      account_ids.each_with_index do |id, index|
        account = Current.family.accounts.find(id)
        account.update!(position: index)
      end
    end

    head :ok
  rescue ArgumentError => e
    # This case should ideally be caught by the `is_a?(Array)` check earlier,
    # but as a fallback or if other argument issues arise with params.
    Rails.logger.error "ArgumentError in AccountsController#update_order: #{e.message}"
    head :bad_request
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "RecordNotFound in AccountsController#update_order: #{e.message}"
    head :not_found
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "RecordInvalid in AccountsController#update_order: #{e.message}"
    # Optionally, you could render json: { error: e.message }, status: :unprocessable_entity
    head :unprocessable_entity
  rescue StandardError => e
    # Catch any other unexpected errors
    Rails.logger.error "StandardError in AccountsController#update_order: #{e.message}\n#{e.backtrace.join("\n")}"
    head :internal_server_error
  end

  private
    def family
      Current.family
    end

    def set_account
      @account = family.accounts.find(params[:id])
    end
end
