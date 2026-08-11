# Underwrites a pending loan application and records the decision.
#
# Two rules decide the outcome, checked in order:
#
#   1. Credit score floor. Below MINIMUM_CREDIT_SCORE the application is denied
#      outright, regardless of income.
#   2. Debt-to-income. The estimated monthly installment may not consume more
#      than MAX_DEBT_TO_INCOME_RATIO of the customer's gross monthly income.
#
# Rule 2 depends on the interest rate, which depends on the credit tier, so the
# rate is priced before the affordability check rather than after it.
#
# Approved applications are priced and given a full payment schedule in the same
# transaction, so an approved loan never exists without its installments.
class LoanApprovalService
  MINIMUM_CREDIT_SCORE = 620

  # The largest share of gross monthly income this single installment may take.
  # Deliberately conservative: a POS lender sees the purchase it is financing but
  # not the customer's other obligations, so it leaves room for them.
  #
  # BigDecimal rather than a float literal, because the ratio it is compared
  # against is a BigDecimal and 0.15 is not exactly representable as a float —
  # a customer landing exactly on the threshold would otherwise be denied.
  MAX_DEBT_TO_INCOME_RATIO = BigDecimal("0.15")

  # Ordered best tier first. The first tier whose threshold the customer clears
  # sets the rate, so the lowest tier here is also the approval floor.
  INTEREST_RATE_TIERS = [
    { minimum_credit_score: 750, rate: 4.9 },
    { minimum_credit_score: 700, rate: 7.9 },
    { minimum_credit_score: 660, rate: 12.9 },
    { minimum_credit_score: MINIMUM_CREDIT_SCORE, rate: 18.9 }
  ].freeze

  def initialize(loan_application)
    @loan_application = loan_application
    @customer = loan_application.customer
  end

  # Returns the loan application with its decision applied.
  def call
    return loan_application unless loan_application.pending?

    loan_application.transaction do
      reason = denial_reason
      reason ? deny!(reason) : approve!
    end

    loan_application
  end

  private

  attr_reader :loan_application, :customer

  # The first rule the application fails, or nil if it passes all of them.
  def denial_reason
    if customer.credit_score < MINIMUM_CREDIT_SCORE
      "Credit score of #{customer.credit_score} is below the minimum required " \
        "score of #{MINIMUM_CREDIT_SCORE}."
    elsif unaffordable?
      "Estimated monthly payment of #{format_money(estimated_monthly_payment)} exceeds " \
        "#{format_percentage(MAX_DEBT_TO_INCOME_RATIO)} of the customer's monthly income " \
        "of #{format_money(customer.monthly_income)}."
    end
  end

  # A customer with no income cannot support any payment, and dividing by their
  # income to prove it would raise, so they are short-circuited here.
  def unaffordable?
    return true if customer.monthly_income <= 0

    estimated_monthly_payment / customer.monthly_income > MAX_DEBT_TO_INCOME_RATIO
  end

  def estimated_monthly_payment
    @estimated_monthly_payment ||= Amortization.monthly_payment(
      principal: loan_application.purchase_amount,
      annual_interest_rate: interest_rate,
      term_months: loan_application.term_months
    )
  end

  def interest_rate
    @interest_rate ||= tier_for(customer.credit_score).fetch(:rate)
  end

  # The lowest tier's threshold is MINIMUM_CREDIT_SCORE, so every application
  # that clears the credit floor matches a tier. If that stops being true this
  # raises rather than quietly pricing a loan at nil.
  def tier_for(credit_score)
    INTEREST_RATE_TIERS.find { |tier| credit_score >= tier[:minimum_credit_score] }
  end

  def approve!
    loan_application.update!(
      status: :approved,
      interest_rate: interest_rate,
      denial_reason: nil,
      decided_at: Time.current
    )

    PaymentScheduleGenerator.new(loan_application).call
  end

  def deny!(reason)
    loan_application.update!(
      status: :denied,
      interest_rate: nil,
      denial_reason: reason,
      decided_at: Time.current
    )
  end

  def format_money(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount)
  end

  def format_percentage(ratio)
    "#{(ratio * 100).round(1)}%"
  end
end
