# One installment of an approved loan's amortization schedule.
class PaymentSchedule < ApplicationRecord
  belongs_to :loan_application

  validates :payment_number, numericality: { only_integer: true, greater_than: 0 },
                             uniqueness: { scope: :loan_application_id }
  validates :due_date, presence: true
  validates :principal_amount, :interest_amount, :total_amount, :remaining_balance,
            numericality: { greater_than_or_equal_to: 0 }
end
