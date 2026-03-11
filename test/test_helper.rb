ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Default to single-worker test runs on Windows/PostgreSQL to avoid
    # fixture FK validation deadlocks. Set TEST_WORKERS>1 to opt in.
    test_workers = ENV.fetch("TEST_WORKERS", "1").to_i
    if test_workers > 1
      parallelize(workers: test_workers, with: :threads)
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
