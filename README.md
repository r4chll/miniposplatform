# Mini POS Financing Platform

[![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](#test-coverage)
[![Ruby](https://img.shields.io/badge/ruby-3.3.6-CC342D)](.ruby-version)
[![Rails](https://img.shields.io/badge/rails-8.1-D30001)](Gemfile)

Point-of-sale installment financing, reduced to the part that actually carries
risk: deciding whether to lend, at what price, and on what repayment schedule.

A customer at a merchant's checkout applies to finance a purchase. The
application is underwritten, priced against the customer's credit tier, and — if
approved — turned into a fixed monthly payment schedule that amortizes the
purchase down to exactly zero.

## Domain

| Model | What it is |
| --- | --- |
| `Merchant` | A retailer offering financing at checkout |
| `Customer` | A borrower, carrying a credit score and annual income |
| `LoanApplication` | One financing request, plus the underwriting decision on it |
| `PaymentSchedule` | One installment of an approved loan's amortization schedule |

## Underwriting

`LoanApprovalService` decides an application against two rules, in order.

**1. Credit score floor — 620.** Below it the application is denied outright,
regardless of income. 620 approves; 619 does not.

**2. Debt-to-income — 15%.** The estimated monthly installment may not consume
more than 15% of the customer's gross monthly income. This is deliberately
conservative: a POS lender can see the purchase it is financing but not the
customer's other obligations, so it leaves room for them.

The second rule needs a payment, and the payment needs a rate, so an application
is priced before it is checked for affordability:

| Credit score | APR |
| --- | --- |
| 750+ | 4.9% |
| 700–749 | 7.9% |
| 660–699 | 12.9% |
| 620–659 | 18.9% |

The lowest tier's threshold is the approval floor, which is what guarantees
every application clearing rule 1 has a price. Approval, pricing and schedule
generation happen in one transaction, so an approved loan never exists without
its installments. An application that has already been decided is left alone.

## Amortization

`PaymentScheduleGenerator` builds the schedule; `Amortization` holds the formula
both it and the underwriter use, so the payment a loan is *approved* at and the
payment it is *scheduled* at can never disagree.

Every installment charges the same total — that is the number quoted at the
register — split between interest on the outstanding balance and principal.
Interest shrinks and principal grows as the balance is paid down.

Three details are load-bearing:

- **All money is `BigDecimal`.** Floats are not safe here; `0.1 + 0.2 != 0.3`,
  and the error compounds across sixty installments.
- **The payment rounds up to the cent, carefully.** Rounding down would leave
  the loan under-amortized. But `(1 + r)⁻ⁿ` is non-terminating, so a payment
  that is exactly $1,010.00 arrives from the division as `1010.000000000000001`,
  and rounding that straight up would charge a spurious extra cent. The value is
  settled below the cent first, which discards the artifact and keeps any real
  fraction. There is a spec for exactly this.
- **The final installment's split is derived from the balance that remains**,
  not recomputed from the rate, so the principal portions sum to *exactly* the
  financed amount and the balance closes at zero rather than a few cents off.

A generated schedule, seeded and printed:

```
Loan: $2500.00 at 18.9% over 12 months
  #1   total   230.28 = principal   190.90 + interest   39.38   balance  2309.10
  #2   total   230.28 = principal   193.91 + interest   36.37   balance  2115.19
  ...
  #11  total   230.28 = principal   223.20 + interest    7.08   balance   226.61
  #12  total   230.28 = principal   226.61 + interest    3.67   balance     0.00
  principal sum: 2500.00 (financed 2500.00)   total repaid: 2763.36
```

## Getting started

```bash
bin/setup --skip-server   # install gems, prepare the database
bin/rails db:seed         # load the sample merchants, customers and applications
bundle exec rspec         # run the suite
```

Ruby 3.3.6, Rails 8.1, SQLite. Drop `--skip-server` to boot the app afterwards.

## Seed data

`db/seeds.rb` is built to land on both sides of every rule, so a seeded database
contains real approvals and real denials rather than six happy paths. Running it
underwrites each application and prints the resulting decisions:

| Customer | Score | Income | Request | Outcome |
| --- | --- | --- | --- | --- |
| Alice Chen | 780 | $95,000 | $8,000 / 24mo | Approved at 4.9% |
| Marco Ruiz | 705 | $62,000 | $15,000 / 36mo | Approved at 7.9% |
| Priya Nair | 620 | $48,000 | $2,500 / 12mo | Approved at 18.9% — exactly on the floor |
| Devon Walsh | 619 | $70,000 | $5,000 / 24mo | Denied — one point below the floor |
| Sofia Petrova | 740 | $24,000 | $20,000 / 36mo | Denied — payment is 31% of income |
| Liam O'Brien | 810 | $18,000 | $3,000 / 12mo | Denied — payment is 17% of income |

The last two are the interesting ones: excellent credit is not sufficient on its
own, and the reason recorded on the application says which rule was missed.

## Tests

```
spec/services/loan_approval_service_spec.rb        approval, denial, boundaries, rate tiers
spec/services/payment_schedule_generator_spec.rb   schedule shape and amortization invariants
spec/services/amortization_spec.rb                 the payment formula itself
spec/factories/                                    FactoryBot definitions
```

Three things the suite is built to catch:

**Boundaries, not just happy paths.** 620 and 619 are both tested, in both
directions. So is a customer with zero income, who would otherwise divide by
zero on the way to a denial.

**Whether the amortization math is actually right.** The single most valuable
test is that the principal portions of a schedule sum to the original purchase
amount — if the math drifts, that fails immediately. But internal consistency
alone cannot prove the *installment size* is correct, since a schedule built
from a wrong payment would still balance perfectly. So the payment formula is
also cross-checked against an independently computed float implementation:
different arithmetic path, same answer. That test is what found the spurious
extra cent described above.

**Rate tiers as a table-driven spec.** One `each` over four `{ score, rate }`
pairs rather than four near-identical blocks; adding a tier is one line.

## Test coverage

100% line and branch coverage, measured by SimpleCov across all of `app/` and
`lib/` — not just the files the suite happens to load, so untested code counts
against the number rather than vanishing from it.

The badge is enforced rather than decorative: a full `bundle exec rspec` fails if
coverage drops below 100%, and CI runs it on every push. Running a single spec
file skips the gate, since exercising one file is a normal thing to do while
working and should not "fail" for not covering the rest of the app.

The test environment eager-loads the application, which both keeps that
measurement honest and verifies on every run that everything still autoloads.

Open `coverage/index.html` after a run for the line-by-line report.
