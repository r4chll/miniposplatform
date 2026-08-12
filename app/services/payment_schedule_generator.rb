# Builds the installment schedule for a priced loan application.
#
# Every installment charges the same total_amount — that is the number quoted at
# the register — split between interest (this month's rate applied to the
# outstanding balance) and principal (whatever is left). Interest therefore
# shrinks and principal grows as the balance is paid down.
#
# The invariant worth protecting is that the principal portions sum to *exactly*
# the financed amount. Rounding each month to the cent leaves a few cents of
# drift over a long term, so the closing installment's split is derived from the
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
      loan_application.payment_schedules.delete_all
      PaymentSchedule.insert_all!(installments)
      loan_application.payment_schedules.reload
    end
  end

  private

  attr_reader :loan_application

  def installments
    balance = loan_application.purchase_amount.to_d
    now = Time.current
    rows = []

    (1..term_months).each do |payment_number|
      interest = (balance * monthly_rate).round(2)
      principal = monthly_payment - interest

      if principal >= balance
        # Closing installment. The principal is whatever is still owed, so the
        # schedule ends at exactly zero and the principal portions sum to the
        # financed amount. Rounding each month up to the cent leaves a small
        # residual; it belongs in interest, which absorbs it while leaving every
        # payment identical. A 0% loan has no interest to absorb it — booking it
        # there would show an interest charge against a 0.00% APR — so its
        # closing payment shrinks by the residual instead.
        principal = balance
        interest = monthly_rate.zero? ? BigDecimal(0) : monthly_payment - balance
      end

      balance -= principal

      rows << {
        loan_application_id: loan_application.id,
        payment_number: payment_number,
        due_date: schedule_start_date >> payment_number,
        principal_amount: principal,
        interest_amount: interest,
        total_amount: principal + interest,
        remaining_balance: balance,
        created_at: now,
        updated_at: now
      }

      # A payment rounded up to the cent repays fractionally more than the
      # schedule needs, so a small enough loan over a long enough term closes
      # before its final month. Continuing would append zero-dollar rows and
      # drive the balance negative.
      break if balance.zero?
    end

    rows
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

  # Due dates are anchored to this date rather than chained off each other. A
  # loan decided on the 31st has a first due date of the 28th in February, and
  # chaining would carry that clamp through the rest of the term, billing every
  # later month three days early.
  def schedule_start_date
    @schedule_start_date ||= (loan_application.decided_at || loan_application.created_at).to_date
  end
end
