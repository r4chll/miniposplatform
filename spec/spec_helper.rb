require "simplecov"

# Started before anything else is required, so that application code loaded by
# rails_helper is instrumented. The `rails` profile tracks every file under
# app/ and lib/ — including ones no spec ever touches — so the reported number
# is coverage of the application, not just of the files the suite happens to
# load.
SimpleCov.start "rails" do
  enable_coverage :branch

  add_group "Services", "app/services"

  # The README badge quotes this suite's coverage. Failing the build when it
  # slips keeps the badge from quietly becoming a lie.
  #
  # Only gated for a full run: `rspec spec/services/amortization_spec.rb` is a
  # normal thing to do while working, and it should not "fail" for the entirely
  # correct reason that it did not exercise the rest of the application.
  minimum_coverage line: 100, branch: 100 if ARGV.none? { |arg| arg.start_with?("spec") }
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "tmp/rspec_examples.txt"
  config.disable_monkey_patching!
  config.warnings = false

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end
