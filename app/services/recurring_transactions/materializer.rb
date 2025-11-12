module RecurringTransactions
  class Materializer
    Result = Struct.new(:processed, :created_entries, :created_transfers, :skipped_existing, :errors, keyword_init: true)

    def self.call(date: nil, family: nil, limit: nil)
      new(date: date, family: family, limit: limit).call
    end

    def initialize(date:, family:, limit:)
      @date = date
      @family = family
      @limit = limit
      @result = Result.new(processed: 0, created_entries: 0, created_transfers: 0, skipped_existing: 0, errors: [])
    end

    def call
      scope = ::RecurringTransaction.active
      scope = scope.where(family_id: @family.id) if @family
      scope = scope.order(next_run_on: :asc, id: :asc)
      scope = scope.limit(@limit) if @limit

      scope.find_each do |rt|
        @result.processed += 1
        begin
          process(rt)
        rescue => e
          @result.errors << { id: rt.id, error: e.class.name, message: e.message }
          Rails.logger.warn("[RecurringTransactions::Materializer] rt=#{rt.id} error=#{e.class} msg=#{e.message}") rescue nil
        end
      end

      @result
    end

    private

    def process(rt)
      local_today = Time.current.in_time_zone(rt.timezone).to_date
      target_date = @date || local_today
      return unless rt.due_on?(target_date)

      run_date = rt.next_run_on
      external_id = rt.build_external_id(run_date)

      if ::Transaction.where(external_id: external_id).exists?
        ActiveRecord::Base.transaction(requires_new: true) do
          rt.advance_next_run!(persist: true)
        end
        @result.skipped_existing += 1
        return
      end

      ActiveRecord::Base.transaction(requires_new: true) do
        if rt.standard?
          create_standard(rt, run_date, external_id)
        elsif rt.transfer?
          create_transfer(rt, run_date, external_id)
        else
          raise "Unsupported kind: #{rt.kind}"
        end

        rt.update!(last_run_on: run_date)
        rt.advance_next_run!(persist: true)
      end
    end

    def create_standard(rt, run_date, external_id)
      attrs = rt.to_entry_attributes(run_date)
      entry = rt.account.entries.create!(
        name: attrs[:entry][:name],
        date: attrs[:entry][:date],
        amount: attrs[:entry][:amount],
        currency: attrs[:entry][:currency],
        notes: attrs[:entry][:notes],
        entryable: ::Transaction.new(
          category_id: attrs[:transaction][:category_id],
          merchant_id: attrs[:transaction][:merchant_id],
          external_id: attrs[:transaction][:external_id]
        )
      )
      entry.sync_account_later
      @result.created_entries += 1
    end

    def create_transfer(rt, run_date, external_id)
      out_entry = rt.account.entries.create!(
        name: rt.name,
        date: run_date,
        amount: rt.amount,
        currency: rt.currency,
        notes: rt.notes,
        entryable: ::Transaction.new(
          category_id: rt.category_id,
          merchant_id: rt.merchant_id,
          external_id: external_id
        )
      )

      in_entry = rt.counter_account.entries.create!(
        name: rt.name,
        date: run_date,
        amount: -rt.amount,
        currency: rt.currency,
        notes: rt.notes,
        entryable: ::Transaction.new(
          category_id: rt.category_id,
          merchant_id: rt.merchant_id,
          external_id: "#{external_id}:counter"
        )
      )

      ::Transfer.create!(inflow_transaction: in_entry.entryable, outflow_transaction: out_entry.entryable)

      out_entry.sync_account_later
      in_entry.sync_account_later

      @result.created_entries += 2
      @result.created_transfers += 1
    end
  end
end