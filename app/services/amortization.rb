# Shared amortization math.
#
# Underwriting (LoanApprovalService) and schedule generation
# (PaymentScheduleGenerator) both need the monthly payment for a loan, and they
# must agree on it to the cent — otherwise a loan could clear the
# debt-to-income check at one payment and then be scheduled at another. Keeping
# the formula in one place is what makes that guarantee cheap.
#
# All arithmetic is BigDecimal. Floats are not safe for money: 0.1 + 0.2 is not
# 0.3, and the error compounds across a 60 month schedule.
module Amortization
  module_function

  # Standard amortizing payment:
  #
  #             r
  #   M = P × ─────────────
  #           1 − (1 + r)⁻ⁿ
  #
  # where P is the financed amount, r the periodic (monthly) rate and n the
  # number of payments.
  #
  # The result is rounded *up* to the cent. Rounding down would leave the loan
  # slightly under-amortized, so the final installment would have to be larger
  # than the rest; rounding up keeps every installment identical, which is what
  # the customer is actually quoted at the point of sale.
  def monthly_payment(principal:, annual_interest_rate:, term_months:)
    principal = principal.to_d
    rate = monthly_rate(annual_interest_rate)

    return round_up_to_cent(principal / term_months) if rate.zero?

    discount_factor = 1 - (1 + rate)**-term_months
    round_up_to_cent(principal * rate / discount_factor)
  end

  # Annual percentage rate (e.g. 7.9) as a monthly decimal rate.
  def monthly_rate(annual_interest_rate)
    annual_interest_rate.to_d / 100 / 12
  end

  # Rounding up has to be done carefully. A payment that works out to exactly
  # $1,010.00 arrives from the division as 1010.000000000000000001, because
  # (1 + r)⁻ⁿ is a non-terminating decimal that BigDecimal has to truncate
  # somewhere. Rounding straight up would charge the customer an extra cent for
  # a figure that was exact. Settling the value well below the cent first
  # discards that artifact while leaving any genuine fraction of a cent intact.
  SETTLING_PRECISION = 6
  private_constant :SETTLING_PRECISION

  def round_up_to_cent(amount)
    amount.round(SETTLING_PRECISION).ceil(2)
  end
end
