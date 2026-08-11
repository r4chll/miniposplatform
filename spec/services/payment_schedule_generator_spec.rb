require "rails_helper"

RSpec.describe PaymentScheduleGenerator do
  let(:customer) { create(:customer, credit_score: 750, annual_income: 80_000) }
  let(:loan_application) do
    create(:loan_application,
           customer: customer,
           purchase_amount: 12_000,
           term_months: 12,
           interest_rate: 7.9,
           status: "approved")
  end

  subject(:generate) { described_class.new(loan_application).call }

  it "creates one payment per month in the term" do
    expect { generate }.to change { loan_application.payment_schedules.count }.by(12)
  end

  it "produces payments whose principal portions sum to the original purchase amount" do
    generate
    total_principal = loan_application.payment_schedules.sum(:principal_amount)
    expect(total_principal).to be_within(0.05).of(loan_application.purchase_amount)
  end

  it "produces a consistent total monthly payment across all installments" do
    generate
    totals = loan_application.payment_schedules.pluck(:total_amount).uniq
    expect(totals.size).to eq(1)
  end

  it "decreases the interest portion and increases the principal portion over time" do
    generate
    schedules = loan_application.payment_schedules.order(:payment_number)
    expect(schedules.first.interest_amount).to be > schedules.last.interest_amount
    expect(schedules.first.principal_amount).to be < schedules.last.principal_amount
  end

  it "pays the balance down to exactly zero on the final installment" do
    generate
    expect(loan_application.payment_schedules.order(:payment_number).last.remaining_balance).to eq(0)
  end

  it "schedules the first payment one month out and one per month after that" do
    generate
    due_dates = loan_application.payment_schedules.order(:payment_number).pluck(:due_date)
    expect(due_dates.first).to eq(loan_application.created_at.to_date >> 1)
    expect(due_dates.last).to eq(loan_application.created_at.to_date >> 12)
  end

  it "replaces the previous schedule when regenerated rather than duplicating it" do
    generate
    expect { described_class.new(loan_application).call }
      .not_to change { loan_application.payment_schedules.count }
  end

  context "when the application has not been priced" do
    let(:unpriced) do
      create(:loan_application, customer: customer, purchase_amount: 12_000, term_months: 12, interest_rate: nil)
    end

    it "refuses to build a schedule" do
      expect { described_class.new(unpriced).call }.to raise_error(ArgumentError, /interest rate/)
    end
  end

  context "with a 0% promotional offer" do
    let(:loan_application) do
      create(:loan_application,
             customer: customer,
             purchase_amount: 1_200,
             term_months: 12,
             interest_rate: 0,
             status: "approved")
    end

    it "charges no interest and splits the principal evenly" do
      generate
      schedules = loan_application.payment_schedules.order(:payment_number)
      expect(schedules.map(&:total_amount).uniq).to eq([ 100 ])
      expect(schedules.map(&:interest_amount).uniq).to eq([ 0 ])
      expect(schedules.sum(&:principal_amount)).to eq(1_200)
    end
  end
end
