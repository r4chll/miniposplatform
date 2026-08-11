FactoryBot.define do
  factory :customer do
    sequence(:email) { |n| "customer#{n}@example.com" }
    first_name { "Test" }
    last_name  { "User" }
    credit_score { 700 }
    annual_income { 60_000 }
  end
end
