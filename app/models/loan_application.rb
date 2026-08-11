# A request to finance a single purchase, and the underwriting decision on it.
class LoanApplication < ApplicationRecord
  STATUSES = { pending: "pending", approved: "approved", denied: "denied" }.freeze

  belongs_to :merchant
  belongs_to :customer
  has_many :payment_schedules, -> { order(:payment_number) }, dependent: :destroy

  enum :status, STATUSES, validate: true

  validates :purchase_amount, numericality: { greater_than: 0 }
  validates :term_months, numericality: { only_integer: true, greater_than: 0 }
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
