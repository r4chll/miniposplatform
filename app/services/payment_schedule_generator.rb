# Builds the installment schedule for a priced loan application.
#
# Every installment charges the same total_amount — that is the number quoted at
# the register — split between interest (this month's rate applied to the
# outstanding balance) and principal (whatever is left). Interest therefore
# shrinks and principal grows as the balance is paid down.
#
# The invariant worth protecting is that the principal portions sum to *exactly*
# the financed amount. Rounding each month to the cent leaves a few cents of
# drift over a long term, so the final installment's split is derived from the
# balance that actually remains rather than recomputed from the rate. See the
# spec for the test that pins this down.
class PaymentScheduleGenerator
  def initialize(loan_application)
    @loan_application = loan_application
  end

  # Replaces any existing schedule, so re-running after a repricing is safe.
  # Returns the persisted installments in payment order.
  def call
    if loan_application.interest_rate.blank?
      raise ArgumentError, "loan application ##{loan_application.id} has no interest rate to amortize"
    end

    loan_application.transaction do
      loan_application.payment_schedules.destroy_all
      installments.map { |attributes| loan_application.payment_schedules.create!(attributes) }
    end
  end

  private

  attr_reader :loan_application

  def installments
    balance = loan_application.purchase_amount.to_d

    (1..term_months).map do |payment_number|
      interest, principal =
        if payment_number == term_months
          # Final installment: the principal is whatever is still owed, so the
          # schedule closes out at exactly zero and the principal portions sum
          # to the financed amount. Interest is the remainder of the fixed
          # payment, which absorbs the accumulated rounding.
          [ monthly_payment - balance, balance ]
        else
          month_interest = (balance * monthly_rate).round(2)
          [ month_interest, monthly_payment - month_interest ]
        end

      balance -= principal

      {
        payment_number: payment_number,
        due_date: first_due_date >> (payment_number - 1),
        principal_amount: principal,
        interest_amount: interest,
        total_amount: monthly_payment,
        remaining_balance: balance
      }
    end
  end

  def monthly_payment
    @monthly_payment ||= Amortization.monthly_payment(
      principal: loan_application.purchase_amount,
      annual_interest_rate: loan_application.interest_rate,
      term_months: term_months
    )
  end

  def monthly_rate
    @monthly_rate ||= Amortization.monthly_rate(loan_application.interest_rate)
  end

  def term_months
    loan_application.term_months
  end

  # First payment falls one month after the decision, or after the application
  # was filed for a loan priced outside the approval service.
  def first_due_date
    @first_due_date ||= (loan_application.decided_at || loan_application.created_at).to_date >> 1
  end
end
