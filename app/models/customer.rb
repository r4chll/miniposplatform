# A borrower applying for financing at the point of sale.
class Customer < ApplicationRecord
  CREDIT_SCORE_RANGE = 300..850

  has_many :loan_applications, dependent: :destroy
  has_many :merchants, through: :loan_applications

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :credit_score, numericality: { only_integer: true, in: CREDIT_SCORE_RANGE }
  validates :annual_income, numericality: { greater_than_or_equal_to: 0 }

  # Gross monthly income, the denominator of the debt-to-income check.
  def monthly_income
    annual_income / 12
  end
end
