FactoryBot.define do
  factory :loan_application do
    merchant
    customer
    purchase_amount { 5_000 }
    term_months { 24 }
    status { "pending" }
  end
end
