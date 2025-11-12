class MaterializeRecurringTransactionsJob < ApplicationJob
  queue_as :scheduled

  def perform(family_id: nil, date: nil, limit: nil)
    family = Family.find(family_id) if family_id
    parsed_date = case date
                  when String then Date.parse(date) rescue nil
                  when Date then date
                  else nil
                  end
    result = RecurringTransactions::Materializer.call(date: parsed_date, family: family, limit: limit)
    Rails.logger.info("[MaterializeRecurringTransactionsJob] #{result.to_h}") rescue nil
    result
  end
end