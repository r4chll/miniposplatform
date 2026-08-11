require "rails_helper"

# Unit specs for the payment formula itself. PaymentScheduleGenerator's specs
# prove the *schedule* is internally consistent — that the principal portions
# add back up to the financed amount. These prove the installment is the right
# size in the first place, which internal consistency alone cannot show: a
# schedule built from a wrong payment would still balance perfectly.
RSpec.describe Amortization do
  describe ".monthly_payment" do
    it "matches the closed-form annuity formula computed independently" do
      principal = 12_000
      annual_rate = 7.9
      term = 12

      # Deliberately plain float arithmetic, so this cross-checks the
      # BigDecimal implementation against a different arithmetic path rather
      # than restating it.
      rate = annual_rate / 100.0 / 12
      expected = principal * rate / (1 - (1 + rate)**-term)

      payment = described_class.monthly_payment(
        principal: principal, annual_interest_rate: annual_rate, term_months: term
      )

      expect(payment).to be_within(0.01).of(expected)
    end

    it "charges principal plus one month of interest on a single-payment loan" do
      payment = described_class.monthly_payment(
        principal: 1_000, annual_interest_rate: 12.0, term_months: 1
      )

      expect(payment).to eq(1_010)
    end

    it "divides the principal evenly when the loan carries no interest" do
      payment = described_class.monthly_payment(
        principal: 1_200, annual_interest_rate: 0, term_months: 12
      )

      expect(payment).to eq(100)
    end

    it "never rounds down, so the loan always fully amortizes" do
      # 1,000 over 3 months does not divide into whole cents.
      payment = described_class.monthly_payment(
        principal: 1_000, annual_interest_rate: 0, term_months: 3
      )

      expect(payment).to eq(BigDecimal("333.34"))
      expect(payment * 3).to be >= 1_000
    end

    it "charges more per month as the rate rises" do
      payments = [ 4.9, 7.9, 12.9, 18.9 ].map do |rate|
        described_class.monthly_payment(principal: 5_000, annual_interest_rate: rate, term_months: 24)
      end

      expect(payments).to eq(payments.sort)
      expect(payments.uniq.size).to eq(4)
    end

    it "returns an exact decimal rather than a float" do
      payment = described_class.monthly_payment(
        principal: 5_000, annual_interest_rate: 7.9, term_months: 24
      )

      expect(payment).to be_a(BigDecimal)
    end
  end

  describe ".monthly_rate" do
    it "converts an annual percentage rate to a monthly decimal rate" do
      expect(described_class.monthly_rate(12.0)).to eq(BigDecimal("0.01"))
    end

    it "is exact for rates a float cannot represent" do
      expect(described_class.monthly_rate(7.2) * 12 * 100).to eq(BigDecimal("7.2"))
    end
  end
end
