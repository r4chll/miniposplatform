require "rails_helper"

RSpec.describe LoanApprovalService do
  subject(:result) { described_class.new(loan_application).call }

  describe "approval path" do
    let(:customer) { create(:customer, credit_score: 780, annual_income: 90_000) }
    let(:loan_application) do
      create(:loan_application, customer: customer, purchase_amount: 6_000, term_months: 24)
    end

    it "approves the loan" do
      expect(result.status).to eq("approved")
    end

    it "assigns an interest rate based on the credit tier" do
      expect(result.interest_rate).to eq(4.9)
    end

    it "generates a payment schedule" do
      expect { result }.to change { PaymentSchedule.count }.by(24)
    end
  end

  describe "credit score boundary" do
    context "exactly at the minimum threshold (620)" do
      let(:customer) { create(:customer, credit_score: 620, annual_income: 60_000) }
      let(:loan_application) { create(:loan_application, customer: customer, purchase_amount: 3_000, term_months: 12) }

      it "approves the loan" do
        expect(result.status).to eq("approved")
      end
    end

    context "one point below the minimum threshold (619)" do
      let(:customer) { create(:customer, credit_score: 619, annual_income: 60_000) }
      let(:loan_application) { create(:loan_application, customer: customer, purchase_amount: 3_000, term_months: 12) }

      it "denies the loan" do
        expect(result.status).to eq("denied")
      end

      it "records the denial reason" do
        expect(result.denial_reason).to match(/credit score/i)
      end
    end
  end

  describe "debt-to-income denial" do
    let(:customer) { create(:customer, credit_score: 800, annual_income: 18_000) }
    let(:loan_application) { create(:loan_application, customer: customer, purchase_amount: 20_000, term_months: 36) }

    it "denies the loan despite excellent credit" do
      expect(result.status).to eq("denied")
    end

    it "records an income ratio denial reason" do
      expect(result.denial_reason).to match(/income/i)
    end
  end

  describe "customers with no income" do
    let(:customer) { create(:customer, credit_score: 800, annual_income: 0) }
    let(:loan_application) { create(:loan_application, customer: customer, purchase_amount: 1_000, term_months: 12) }

    it "denies the loan rather than dividing by zero" do
      expect(result.status).to eq("denied")
    end

    it "records an income denial reason" do
      expect(result.denial_reason).to match(/income/i)
    end
  end

  describe "an application that has already been decided" do
    let(:customer) { create(:customer, credit_score: 780, annual_income: 90_000) }
    let(:loan_application) do
      create(:loan_application, customer: customer, purchase_amount: 6_000, term_months: 24,
                                status: "denied", denial_reason: "Declined by manual risk review.")
    end

    it "leaves the existing decision in place" do
      expect(result.status).to eq("denied")
      expect(result.denial_reason).to eq("Declined by manual risk review.")
    end

    it "does not generate a payment schedule" do
      expect { result }.not_to change { PaymentSchedule.count }
    end
  end

  describe "interest rate tiers" do
    [
      { score: 800, expected_rate: 4.9 },
      { score: 720, expected_rate: 7.9 },
      { score: 670, expected_rate: 12.9 },
      { score: 630, expected_rate: 18.9 }
    ].each do |tier|
      context "credit score #{tier[:score]}" do
        let(:customer) { create(:customer, credit_score: tier[:score], annual_income: 80_000) }
        let(:loan_application) { create(:loan_application, customer: customer, purchase_amount: 4_000, term_months: 12) }

        it "assigns rate #{tier[:expected_rate]}" do
          expect(result.interest_rate).to eq(tier[:expected_rate])
        end
      end
    end
  end
end
