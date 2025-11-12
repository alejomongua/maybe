class RecurringTransaction < ApplicationRecord
  belongs_to :family
  belongs_to :account
  belongs_to :counter_account, class_name: "Account", optional: true
  belongs_to :category, optional: true
  belongs_to :merchant, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  enum kind: { standard: 0, transfer: 1 }
  enum weekend_strategy: { none: 0, following: 1, preceding: 2, nearest: 3, last_day: 4 }
  enum status: { active: 0, paused: 1, archived: 2 }

  validates :family, :account, :name, :amount, :currency, :day_of_month, 
            :interval_months, :start_on, :timezone, :status, :kind, :next_run_on, presence: true

  validates :amount, numericality: { other_than: 0 }
  validates :interval_months, numericality: { greater_than_or_equal_to: 1 }
  validates :day_of_month, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }

  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

  validate :currency_valid
  validate :date_range_valid
  validate :transfer_configuration_valid
  validate :same_family_integrity

  before_validation :set_defaults

  # Scheduling helpers
  def next_scheduled_date(from_date:)
    target_month = from_date.advance(months: interval_months)
    
    # Handle last_day strategy
    if weekend_strategy == "last_day"
      return target_month.end_of_month
    end

    # Clamp day to valid range for target month
    candidate = clamp_to_month(target_month, day_of_month)
    
    # Apply weekend strategy
    apply_weekend_strategy(candidate)
  end

  def advance_next_run!(persist: true)
    self.last_run_on = next_run_on
    self.next_run_on = next_scheduled_date(from_date: last_run_on + 1.day)
    save! if persist
  end

  def due_on?(date = local_today)
    status == "active" && 
      next_run_on.present? && 
      next_run_on <= date && 
      (end_on.nil? || date <= end_on)
  end

  def overdue?
    status == "active" && next_run_on.present? && next_run_on < local_today
  end

  def build_external_id(run_date)
    "rt:#{id}:#{run_date.strftime('%Y%m%d')}"
  end

  def to_entry_attributes(run_date)
    {
      entry: {
        account_id: account_id,
        name: name,
        date: run_date,
        amount: amount,
        currency: currency,
        notes: notes
      },
      transaction: {
        category_id: category_id,
        merchant_id: merchant_id,
        external_id: build_external_id(run_date)
      }
    }
  end

  private

  def set_defaults
    self.timezone ||= family&.timezone
    self.currency ||= account&.currency
    self.next_run_on ||= compute_initial_next_run if start_on.present?
  end

  def compute_initial_next_run
    next_scheduled_date(from_date: start_on)
  end

  def currency_valid
    return if currency.blank?
    
    # Try Money::Currency validation if available
    begin
      Money::Currency.new(currency) if defined?(Money::Currency)
    rescue Money::Currency::UnknownCurrency
      errors.add(:currency, "is not a valid currency code")
      return
    rescue => e
      # Fallback to simple length check if Money validation fails
      unless currency.length.between?(3, 10)
        errors.add(:currency, "must be between 3 and 10 characters")
      end
    end
  end

  def date_range_valid
    return unless start_on.present? && end_on.present?
    
    if end_on < start_on
      errors.add(:end_on, "must be on or after start date")
    end
  end

  def transfer_configuration_valid
    return unless transfer?

    if counter_account_id.blank?
      errors.add(:counter_account, "is required for transfers")
    end

    if account_id == counter_account_id
      errors.add(:counter_account, "must be different from account")
    end
  end

  def same_family_integrity
    if account && account.family_id != family_id
      errors.add(:account, "must belong to same family")
    end

    if counter_account && counter_account.family_id != family_id
      errors.add(:counter_account, "must belong to same family")
    end

    if category && category.respond_to?(:family_id) && category.family_id != family_id
      errors.add(:category, "must belong to same family")
    end

    if merchant && merchant.respond_to?(:family_id) && merchant.family_id != family_id
      errors.add(:merchant, "must belong to same family")
    end
  end

  def local_today
    Time.current.in_time_zone(timezone).to_date
  end

  def apply_weekend_strategy(date)
    return date if weekend_strategy == "none"
    return date.end_of_month if weekend_strategy == "last_day"
    return date if business_day?(date)

    case weekend_strategy
    when "following"
      following_business_day(date)
    when "preceding"
      preceding_business_day(date)
    when "nearest"
      # Choose the closer business day, preferring the one in the same month
      following = following_business_day(date)
      preceding = preceding_business_day(date)
      
      # If one falls outside the month, prefer the one that stays in month
      if following.month != date.month && preceding.month == date.month
        preceding
      elsif preceding.month != date.month && following.month == date.month
        following
      else
        # Both in same month or both outside - choose nearest
        date.saturday? ? preceding : following
      end
    else
      date
    end
  end

  def business_day?(date)
    !date.saturday? && !date.sunday?
  end

  def following_business_day(date)
    candidate = date
    candidate += 1.day until business_day?(candidate)
    candidate
  end

  def preceding_business_day(date)
    candidate = date
    candidate -= 1.day until business_day?(candidate)
    candidate
  end

  def clamp_to_month(date, day)
    last_day = date.end_of_month.day
    actual_day = [day, last_day].min
    date.change(day: actual_day)
  end
end