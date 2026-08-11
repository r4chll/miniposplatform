# A retailer that offers point-of-sale financing to its customers.
class Merchant < ApplicationRecord
  INDUSTRIES = %w[home_improvement auto retail healthcare electronics].freeze

  has_many :loan_applications, dependent: :destroy
  has_many :customers, through: :loan_applications

  validates :name, presence: true
  validates :industry, presence: true, inclusion: { in: INDUSTRIES }
end
