# Recurring Transactions Technical Design Specification

## 1. Data Model

### Table: `recurring_transactions`

```ruby
create_table :recurring_transactions, id: :uuid do |t|
  # Core relationships
  t.uuid     :family_id,            null: false, index: true
  t.uuid     :account_id,           null: false, index: true
  t.uuid     :counter_account_id,   index: true  # For transfers only
  
  # Transaction template
  t.string   :kind,                 null: false, default: "standard"
  t.string   :name,                 null: false
  t.text     :notes
  t.decimal  :amount,               null: false, precision: 19, scale: 4
  t.string   :currency,             null: false
  t.uuid     :category_id,          index: true
  t.uuid     :merchant_id,          index: true
  
  # Recurrence pattern
  t.integer  :day_of_month,         null: false  # 1..31
  t.integer  :interval_months,      null: false, default: 1
  t.string   :weekend_strategy,     null: false, default: "none"
  t.date     :start_on,             null: false
  t.date     :end_on
  
  # Execution tracking
  t.date     :next_run_on,          null: false, index: true
  t.date     :last_run_on
  
  # Configuration snapshot
  t.string   :timezone,             null: false
  t.string   :status,               null: false, default: "active", index: true
  
  # Audit
  t.uuid     :created_by_id
  t.integer  :lock_version,         default: 0
  
  t.timestamps
end
```

### Indexes

```ruby
# Composite indexes for efficient queries
add_index :recurring_transactions, [:family_id, :status, :next_run_on], 
  name: "index_rt_on_family_status_next_run"

add_index :recurring_transactions, [:account_id]
add_index :recurring_transactions, [:counter_account_id]
add_index :recurring_transactions, [:kind]

# Partial index for active records (PostgreSQL)
execute <<-SQL
  CREATE INDEX index_rt_active_next_run 
  ON recurring_transactions (next_run_on) 
  WHERE status = 'active' AND next_run_on IS NOT NULL
SQL
```

### Enums

```ruby
enum :kind, {
  standard: "standard",    # Regular transaction
  transfer: "transfer"     # Transfer between accounts
}, validate: true

enum :weekend_strategy, {
  none: "none",            # No adjustment
  following: "following",  # Next business day
  preceding: "preceding",  # Previous business day
  nearest: "nearest",      # Closest business day
  last_day: "last_day"     # Force to last day of month
}, validate: true

enum :status, {
  active: "active",        # Currently processing
  paused: "paused",        # Temporarily disabled
  archived: "archived"     # Permanently disabled
}, validate: true
```

### Foreign Keys & Constraints

```ruby
add_foreign_key :recurring_transactions, :families
add_foreign_key :recurring_transactions, :accounts
add_foreign_key :recurring_transactions, :accounts, column: :counter_account_id
add_foreign_key :recurring_transactions, :categories
add_foreign_key :recurring_transactions, :merchants, column: :merchant_id
add_foreign_key :recurring_transactions, :users, column: :created_by_id

# DB constraint: ensure external_id index exists on transactions
add_index :transactions, :external_id, unique: true, algorithm: :concurrently, 
  if_not_exists: true
```

## 2. Model: `RecurringTransaction`

### Location
`app/models/recurring_transaction.rb`

### Validations

```ruby
class RecurringTransaction < ApplicationRecord
  belongs_to :family
  belongs_to :account
  belongs_to :counter_account, class_name: "Account", optional: true
  belongs_to :category, optional: true
  belongs_to :merchant, class_name: "FamilyMerchant", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  
  validates :family, :account, :name, :amount, :currency, 
            :day_of_month, :start_on, :timezone, :status, :kind, presence: true
  
  validates :amount, numericality: { other_than: 0 }
  validates :interval_months, numericality: { greater_than_or_equal_to: 1 }
  validates :day_of_month, numericality: { 
    greater_than_or_equal_to: 1, 
    less_than_or_equal_to: 31 
  }
  
  validates :weekend_strategy, inclusion: { in: weekend_strategies.keys }
  validates :status, inclusion: { in: statuses.keys }
  validates :kind, inclusion: { in: kinds.keys }
  
  validates :currency, inclusion: { 
    in: -> (_) { Money.available_currencies }
  }
  
  validates :timezone, inclusion: { 
    in: ActiveSupport::TimeZone.all.map(&:name) 
  }
  
  validate :date_range_valid
  validate :transfer_configuration_valid
  validate :same_family_accounts
  
  private
  
  def date_range_valid
    return unless start_on && end_on
    errors.add(:end_on, "must be after start date") if end_on < start_on
  end
  
  def transfer_configuration_valid
    return unless transfer?
    
    errors.add(:counter_account, "is required for transfers") unless counter_account_id
    errors.add(:counter_account, "must be different from account") if account_id == counter_account_id
    
    # Optionally restrict to same currency transfers
    if counter_account && account.currency != counter_account.currency
      errors.add(:counter_account, "must use same currency as source account")
    end
  end
  
  def same_family_accounts
    if account && account.family_id != family_id
      errors.add(:account, "must belong to same family")
    end
    
    if counter_account && counter_account.family_id != family_id
      errors.add(:counter_account, "must belong to same family")
    end
  end
end
```

### Business Logic Methods

```ruby
# Calculate next scheduled date
def next_scheduled_date(from_date:)
  candidate = from_date + interval_months.months
  
  # Adjust day if needed
  candidate = candidate.change(day: [day_of_month, candidate.end_of_month.day].min)
  
  # Apply weekend strategy
  apply_weekend_strategy(candidate)
end

def apply_weekend_strategy(date)
  return date if weekend_strategy == "none"
  return date.end_of_month if weekend_strategy == "last_day"
  
  return date unless date.saturday? || date.sunday?
  
  case weekend_strategy
  when "following"
    date + (date.saturday? ? 2.days : 1.day)
  when "preceding"
    date - (date.sunday? ? 2.days : 1.day)
  when "nearest"
    if date.saturday?
      (date - 1.day).month == date.month ? date - 1.day : date + 2.days
    else  # Sunday
      (date + 1.day).month == date.month ? date + 1.day : date - 2.days
    end
  else
    date
  end
end

# Advance to next run date
def advance_next_run!
  update!(
    last_run_on: next_run_on,
    next_run_on: next_scheduled_date(from_date: next_run_on)
  )
end

# Check if due
def due_on?(date)
  next_run_on <= date
end

def overdue?
  local_today = Time.now.in_time_zone(timezone).to_date
  next_run_on < local_today
end

# Build external ID for idempotency
def build_external_id(run_date)
  "rt:#{id}:#{run_date.strftime('%Y%m%d')}"
end

# Snapshot template attributes for entry creation
def to_entry_attributes(run_date)
  {
    date: run_date,
    name: name,
    notes: notes,
    amount: amount,
    currency: currency,
    entryable_attributes: {
      category_id: category_id,
      merchant_id: merchant_id,
      kind: determine_transaction_kind,
      external_id: build_external_id(run_date)
    }
  }
end

private

def determine_transaction_kind
  return "standard" if standard?
  
  # For transfers, determine based on counter_account type
  Transfer.kind_for_account(counter_account)
end
```

## 3. Materialization Service

### Location
`app/services/recurring_transactions/materializer.rb`

### Implementation

```ruby
module RecurringTransactions
  class Materializer
    attr_reader :target_date, :family_scope
    
    def initialize(target_date: nil, family: nil)
      @target_date = target_date
      @family_scope = family
    end
    
    def materialize
      results = { created: 0, skipped: 0, errors: [] }
      
      due_recurrences.find_each do |rt|
        begin
          process_recurring_transaction(rt)
          results[:created] += 1
        rescue => e
          results[:errors] << { id: rt.id, error: e.message }
        end
      end
      
      results
    end
    
    private
    
    def due_recurrences
      scope = RecurringTransaction.active.includes(:account, :counter_account)
      scope = scope.where(family: family_scope) if family_scope
      
      # Filter by timezone-aware "today" for each record
      scope.select do |rt|
        local_today = Time.now.in_time_zone(rt.timezone).to_date
        target = @target_date || local_today
        rt.next_run_on && rt.next_run_on <= target
      end
    end
    
    def process_recurring_transaction(rt)
      run_date = rt.next_run_on
      external_id = rt.build_external_id(run_date)
      
      # Idempotency check
      if Transaction.exists?(external_id: external_id)
        rt.advance_next_run!
        return
      end
      
      RecurringTransaction.transaction do
        if rt.standard?
          create_standard_transaction(rt, run_date)
        elsif rt.transfer?
          create_transfer(rt, run_date)
        end
        
        rt.advance_next_run!
      end
    end
    
    def create_standard_transaction(rt, run_date)
      attrs = rt.to_entry_attributes(run_date)
      
      entry = rt.account.entries.create!(attrs)
      entry.sync_account_later
      
      entry
    end
    
    def create_transfer(rt, run_date)
      # Create outflow entry
      outflow_attrs = rt.to_entry_attributes(run_date)
      outflow_attrs[:amount] = rt.amount  # Use stored amount (negative for outflow)
      
      outflow_entry = rt.account.entries.build(outflow_attrs)
      outflow_entry.entryable.kind = Transfer.kind_for_account(rt.counter_account)
      outflow_entry.save!
      
      # Create inflow entry
      inflow_attrs = rt.to_entry_attributes(run_date)
      inflow_attrs[:amount] = -rt.amount  # Opposite sign
      inflow_attrs[:entryable_attributes][:external_id] = "#{rt.build_external_id(run_date)}_inflow"
      inflow_attrs[:entryable_attributes][:kind] = Transfer.kind_for_account(rt.counter_account)
      
      inflow_entry = rt.counter_account.entries.create!(inflow_attrs)
      
      # Link with Transfer
      transfer = Transfer.create!(
        inflow_transaction: inflow_entry.entryable,
        outflow_transaction: outflow_entry.entryable
      )
      
      # Sync both accounts
      outflow_entry.sync_account_later
      inflow_entry.sync_account_later
      
      transfer
    end
  end
end
```

## 4. Background Job

### Location
`app/jobs/materialize_recurring_transactions_job.rb`

### Implementation

```ruby
class MaterializeRecurringTransactionsJob < ApplicationJob
  queue_as :scheduled
  
  def perform
    results = { families_processed: 0, total_created: 0, total_errors: 0 }
    
    Family.find_each do |family|
      next unless family.timezone.present?
      
      family_results = RecurringTransactions::Materializer.new(
        family: family
      ).materialize
      
      results[:families_processed] += 1
      results[:total_created] += family_results[:created]
      results[:total_errors] += family_results[:errors].size
      
      log_errors(family, family_results[:errors]) if family_results[:errors].any?
    end
    
    Rails.logger.info(
      "Recurring transactions materialized: #{results[:total_created]} created, " \
      "#{results[:total_errors]} errors across #{results[:families_processed]} families"
    )
    
    results
  end
  
  private
  
  def log_errors(family, errors)
    errors.each do |error|
      Rails.logger.error(
        "Failed to materialize recurring transaction #{error[:id]} " \
        "for family #{family.id}: #{error[:error]}"
      )
    end
  end
end
```

## 5. Scheduling

### Location
`config/schedule.yml`

### Configuration

```yaml
materialize_recurring_transactions:
  cron: "15 8 * * *"  # Daily at 08:15 UTC
  class: MaterializeRecurringTransactionsJob
  queue: scheduled
  description: "Materializes due recurring transactions for all families"
```

**Rationale for timing:** Running at 08:15 UTC ensures:
- Covers US timezones (early morning 12:15-3:15 AM)
- Covers EU timezones (mid-morning 9:15-10:15 AM)
- Covers Asia/Pacific timezones (afternoon/evening)
- Avoids conflict with market data import (22:00 UTC)

## 6. Controller & UI

### Controller: `RecurringTransactionsController`

**Location:** `app/controllers/recurring_transactions_controller.rb`

```ruby
class RecurringTransactionsController < ApplicationController
  before_action :set_recurring_transaction, only: [:show, :edit, :update, :destroy, :pause, :resume]
  
  def index
    @recurring_transactions = Current.family.recurring_transactions
                                            .includes(:account, :counter_account, :category, :merchant)
                                            .order(next_run_on: :asc)
  end
  
  def new
    @recurring_transaction = Current.family.recurring_transactions.build(
      currency: Current.family.currency,
      timezone: Current.family.timezone,
      interval_months: 1,
      status: :active
    )
  end
  
  def create
    @recurring_transaction = Current.family.recurring_transactions.build(
      recurring_transaction_params.merge(created_by: Current.user)
    )
    
    if @recurring_transaction.save
      redirect_to recurring_transactions_path, notice: "Recurring transaction created"
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def update
    if @recurring_transaction.update(recurring_transaction_params)
      redirect_to recurring_transactions_path, notice: "Recurring transaction updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @recurring_transaction.destroy
    redirect_to recurring_transactions_path, notice: "Recurring transaction deleted"
  end
  
  def pause
    @recurring_transaction.update!(status: :paused)
    redirect_to recurring_transactions_path, notice: "Recurring transaction paused"
  end
  
  def resume
    @recurring_transaction.update!(status: :active)
    redirect_to recurring_transactions_path, notice: "Recurring transaction resumed"
  end
  
  private
  
  def set_recurring_transaction
    @recurring_transaction = Current.family.recurring_transactions.find(params[:id])
  end
  
  def recurring_transaction_params
    params.require(:recurring_transaction).permit(
      :account_id, :counter_account_id, :kind, :name, :notes, 
      :amount, :currency, :category_id, :merchant_id,
      :day_of_month, :interval_months, :weekend_strategy,
      :start_on, :end_on, :timezone, :status
    )
  end
end
```

### Routes

```ruby
resources :recurring_transactions do
  member do
    patch :pause
    patch :resume
  end
end
```

### UI Surface (Views Outline)

**Index (`index.html.erb`):**
- Table with columns: Name, Account, Amount, Frequency, Next Run, Last Run, Status
- Actions: Edit, Pause/Resume, Delete
- Bulk actions: Pause selected, Resume selected
- Filter by status, account

**Form (`_form.html.erb`):**
- Account selector (required)
- Kind radio: Standard / Transfer
- Counter account selector (shown if transfer)
- Name (text input)
- Notes (textarea)
- Amount (number input with currency)
- Currency selector (defaults to account currency)
- Category selector (optional)
- Merchant selector (optional)
- Day of month (1-31 selector)
- Interval months (default 1)
- Weekend strategy selector
- Start date (date picker)
- End date (date picker, optional)
- Timezone (defaults to family timezone, locked)
- Status (Active/Paused)

**UX Defaults:**
- Currency: auto-fill from selected account
- Timezone: lock to family timezone (display but disable editing)
- Interval: default to 1 (monthly)
- Weekend strategy: default to "none"
- Next run: auto-calculate from start_on + day_of_month

## 7. Testing Plan

### Model Tests (`test/models/recurring_transaction_test.rb`)

```ruby
# Validations
- validates presence of required fields
- validates amount != 0
- validates day_of_month in 1..31
- validates transfer has counter_account
- validates transfer accounts are different
- validates same family for all accounts
- validates currency is valid ISO code
- validates timezone is valid

# Business logic
- next_scheduled_date calculates correctly
  - handles month-end edge cases (Feb 29, 31st days)
  - respects interval_months
- weekend_strategy application
  - none: no change
  - following: moves to Monday
  - preceding: moves to Friday
  - nearest: picks closest business day
  - last_day: forces to EOM
- build_external_id format
- to_entry_attributes structure
```

### Service Tests (`test/services/recurring_transactions/materializer_test.rb`)

```ruby
# Core functionality
- creates Entry + Transaction for standard recurring
- creates paired Entries + Transfer for transfer recurring
- sets external_id on transactions
- calls sync_account_later on created entries

# Idempotency
- skips creation if external_id exists
- advances next_run_on even when skipping

# Timezone correctness
- evaluates due_on? per record timezone
- processes records due in their local timezone

# Edge cases
- handles day_of_month > days in month (e.g., 31 in Feb)
- respects end_on date (stops creating after)
- handles errors gracefully per record
```

### Transfer Tests

```ruby
# Transfer creation
- creates outflow on source account
- creates inflow on counter_account
- amounts are opposite signs
- both transactions have correct kind
- Transfer links both transactions
- both accounts enqueue sync

# Validations
- prevents cross-family transfers
- enforces same currency (if constrained)
```

### Job Test (`test/jobs/materialize_recurring_transactions_job_test.rb`)

```ruby
# Execution
- processes all families
- calls materializer per family
- logs summary
- handles errors per family
```

### Controller Tests (`test/controllers/recurring_transactions_controller_test.rb`)

```ruby
# CRUD operations
- index lists family's recurring transactions
- new renders form with defaults
- create saves valid recurring transaction
- update modifies existing recurring transaction
- destroy removes recurring transaction

# Actions
- pause changes status to paused
- resume changes status to active

# Authorization
- scopes to Current.family
- rejects cross-family access
```

### Fixtures (`test/fixtures/recurring_transactions.yml`)

```yaml
monthly_rent:
  family: one
  account: checking
  kind: standard
  name: Rent Payment
  amount: -2000.00
  currency: USD
  day_of_month: 1
  interval_months: 1
  weekend_strategy: none
  start_on: <%= 6.months.ago.to_date %>
  next_run_on: <%= Date.today.beginning_of_month %>
  timezone: America/New_York
  status: active

paycheck:
  family: one
  account: checking
  kind: standard
  name: Salary
  amount: 3500.00
  currency: USD
  category: salary
  day_of_month: 15
  interval_months: 1
  weekend_strategy: preceding
  start_on: <%= 1.year.ago.to_date %>
  next_run_on: <%= Date.today.change(day: 15) %>
  timezone: America/New_York
  status: active
```

## 8. Migration Plan

### Phase 1: Schema Migration

```ruby
class CreateRecurringTransactions < ActiveRecord::Migration[7.2]
  def change
    # Create enum types
    create_enum :recurring_transaction_kind, %w[standard transfer]
    create_enum :recurring_transaction_weekend_strategy, 
                %w[none following preceding nearest last_day]
    create_enum :recurring_transaction_status, %w[active paused archived]
    
    create_table :recurring_transactions, id: :uuid do |t|
      # [Full schema as detailed in section 1]
    end
    
    # Add indexes
    # [All indexes as detailed in section 1]
    
    # Add foreign keys
    # [All FKs as detailed in section 1]
    
    # Ensure external_id unique index on transactions
    add_index :transactions, :external_id, unique: true, 
              algorithm: :concurrently, if_not_exists: true
  end
end
```

### Phase 2: Deployment Strategy

**Step 1: Deploy Schema**
- Run migration
- Deploy model + validations (no UI, no job)
- Monitor for issues

**Step 2: Deploy Service + Job**
- Deploy materializer service
- Deploy background job
- Add to schedule.yml
- Test manually via Rails console
- Monitor first automated run

**Step 3: Deploy UI**
- Deploy controller + views
- Enable routes
- User acceptance testing
- Monitor usage patterns

### Rollback Strategy

If issues arise:
1. Disable cron job immediately (remove from schedule.yml)
2. Pause all active recurring_transactions: 
   ```ruby
   RecurringTransaction.active.update_all(status: :paused)
   ```
3. Investigate materialized transactions via external_id pattern
4. Fix issues and re-enable gradually

### Data Integrity Checks

```ruby
# Verify no orphaned records
RecurringTransaction.where.not(family_id: Family.select(:id)).exists?

# Verify no cross-family accounts
RecurringTransaction.joins(:account)
  .where.not("accounts.family_id = recurring_transactions.family_id")
  .exists?

# Verify external_id uniqueness
Transaction.group(:external_id).having("COUNT(*) > 1").count
```

## 9. Non-Goals (v1)

Explicitly **not included** in initial release:

- **Weekly/biweekly schedules** - Only monthly intervals supported
- **Quarterly/annual frequencies** - Use interval_months only
- **Variable amounts** - Amount is fixed per template
- **Proration logic** - No partial-month calculations
- **Business holiday calendars** - Only weekend awareness
- **Tag templates** - Tags not supported on recurring transactions
- **Multi-currency transfers** - Transfers must use same currency
- **Approval workflows** - Transactions materialize automatically
- **Notifications** - No email/SMS alerts on materialization
- **Retroactive materialization** - Does not backfill missed dates on creation

## 10. Future Enhancements (v2+)

Potential improvements for future iterations:

1. **Flexible frequencies:** Weekly, biweekly, quarterly, annual
2. **Smart scheduling:** "Last Friday of month", "Second Tuesday"
3. **Variable amounts:** Formulas, inflation adjustment, % of balance
4. **Tag support:** Apply tags to materialized transactions
5. **Notifications:** Alert users before/after materialization
6. **Approval mode:** Review before auto-creation
7. **Bulk operations:** Clone, bulk pause/resume
8. **Analytics:** Track recurring vs. one-time spending
9. **Suggestions:** ML-based recurring transaction detection
10. **Calendar integration:** Export to iCal/Google Calendar

---

## Implementation Contract

This specification provides a complete technical design for recurring transactions materialization that:

✅ **Integrates seamlessly** with existing Entry/Transaction/Transfer models  
✅ **Maintains conventions** (UUIDs, family scoping, delegated types, sync patterns)  
✅ **Ensures idempotency** via external_id collision detection  
✅ **Handles timezones** correctly with per-record timezone evaluation  
✅ **Scales efficiently** with indexes and background processing  
✅ **Provides clear UI** for CRUD operations  
✅ **Includes comprehensive testing** strategy  
✅ **Defines safe migration** path with phased rollout  

The design is ready for implementation in Code mode with all architectural decisions documented and aligned with codebase patterns.