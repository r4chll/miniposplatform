# Lets specs call `create(...)` and `build(...)` without the FactoryBot prefix.
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
