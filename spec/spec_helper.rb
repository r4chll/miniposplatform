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
  # Gated on CI, which always runs the whole suite. Locally, `rspec <one_file>`,
  # `rspec --only-failures` and `rspec -e "..."` are all normal things to do
  # while working, and none of them should "fail" for the entirely correct
  # reason that they did not exercise the rest of the application. Inspecting
  # ARGV to tell those apart cannot work: this block runs long before RSpec has
  # resolved which examples it will actually run.
  # Plain Ruby, not `present?` — this runs before Rails is loaded.
  minimum_coverage line: 100, branch: 100 unless ENV["CI"].to_s.empty?
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
