# Development seed data.
#
# The customers below are chosen to land on each side of every underwriting
# rule, so `rails db:seed` produces a database with a real approval, a real
# credit denial and a real affordability denial in it rather than six happy
# paths. Idempotent: re-running replaces the previous seed set.
#
# Development only, and it means it. The deletes below are unscoped, and
# `db:prepare` runs seeds automatically on a database it considers newly
# prepared, so an unguarded run against real data would empty all four tables.

unless Rails.env.development?
  abort "db/seeds.rb deletes every merchant, customer, application and schedule. Refusing to run in #{Rails.env}."
end

PaymentSchedule.delete_all
LoanApplication.delete_all
Customer.delete_all
Merchant.delete_all

merchants = Merchant.create!([
  { name: "Home Reno Depot", industry: "home_improvement" },
  { name: "Northside Auto", industry: "auto" },
  { name: "Urban Furnishings", industry: "retail" }
])

customers = Customer.create!([
  # Clearly approved: high credit score, healthy income
  { first_name: "Alice", last_name: "Chen", email: "alice@example.com",
    credit_score: 780, annual_income: 95_000 },

  # Approved, but at the lower interest tier
  { first_name: "Marco", last_name: "Ruiz", email: "marco@example.com",
    credit_score: 705, annual_income: 62_000 },

  # Right at the minimum credit threshold (620), should still approve
  { first_name: "Priya", last_name: "Nair", email: "priya@example.com",
    credit_score: 620, annual_income: 48_000 },

  # One point below threshold, should deny on credit score
  { first_name: "Devon", last_name: "Walsh", email: "devon@example.com",
    credit_score: 619, annual_income: 70_000 },

  # Good credit, but income too low for the requested purchase amount
  { first_name: "Sofia", last_name: "Petrova", email: "sofia@example.com",
    credit_score: 740, annual_income: 24_000 },

  # Edge case: very low income, should hit debt-to-income denial
  { first_name: "Liam", last_name: "OBrien", email: "liam@example.com",
    credit_score: 810, annual_income: 18_000 }
])

# A spread of purchase amounts and terms
loan_applications = LoanApplication.create!([
  { merchant: merchants[0], customer: customers[0], purchase_amount: 8_000, term_months: 24 },
  { merchant: merchants[1], customer: customers[1], purchase_amount: 15_000, term_months: 36 },
  { merchant: merchants[2], customer: customers[2], purchase_amount: 2_500, term_months: 12 },
  { merchant: merchants[0], customer: customers[3], purchase_amount: 5_000, term_months: 24 },
  { merchant: merchants[1], customer: customers[4], purchase_amount: 20_000, term_months: 36 },
  { merchant: merchants[2], customer: customers[5], purchase_amount: 3_000, term_months: 12 }
])

# Run each application through underwriting so the seeded database also contains
# priced loans and their payment schedules, not just untouched requests.
loan_applications.each { |application| LoanApprovalService.new(application).call }

puts "Seeded #{Merchant.count} merchants, #{Customer.count} customers, #{LoanApplication.count} loan applications."
puts "Decisions: #{LoanApplication.group(:status).count.sort.to_h}"
puts "Generated #{PaymentSchedule.count} scheduled payments."
