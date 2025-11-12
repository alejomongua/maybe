class RecurringTransactionsController < ApplicationController
  before_action :set_recurring_transaction, only: [:edit, :update, :destroy, :pause, :resume]

  def index
    @recurring_transactions = Current.family.recurring_transactions.order(:next_run_on, :id)
  end

  def new
    @recurring_transaction = Current.family.recurring_transactions.new
  end

  def create
    @recurring_transaction = Current.family.recurring_transactions.new(rt_params.merge(created_by: Current.user))
    if @recurring_transaction.save
      redirect_to recurring_transactions_path, notice: "Recurring transaction created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @recurring_transaction.update(rt_params)
      redirect_to recurring_transactions_path, notice: "Recurring transaction updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_transaction.destroy
    redirect_to recurring_transactions_path, notice: "Recurring transaction deleted successfully."
  end

  def pause
    @recurring_transaction.paused!
    redirect_to recurring_transactions_path, notice: "Recurring transaction paused."
  end

  def resume
    @recurring_transaction.active!
    redirect_to recurring_transactions_path, notice: "Recurring transaction resumed."
  end

  private

  def set_recurring_transaction
    @recurring_transaction = Current.family.recurring_transactions.find(params[:id])
  end

  def rt_params
    params.require(:recurring_transaction).permit(
      :account_id, :counter_account_id, :kind, :name, :notes, :amount, :currency,
      :category_id, :merchant_id, :day_of_month, :interval_months, :weekend_strategy,
      :start_on, :end_on, :timezone, :status
    )
  end
end