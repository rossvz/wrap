ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  def sign_in_as(user)
    db_session = user.sessions.create!(
      user_agent: "Test Browser",
      ip_address: "127.0.0.1"
    )
    # For integration tests, we need to use the cookies jar properly
    # The session id needs to be signed the same way the controller does it
    post session_url, params: { email_address: user.email_address }
    # Consume the magic link that was just created
    magic_link = user.magic_links.last
    post session_magic_link_url, params: { code: magic_link.code }
  end

  def sign_out
    delete session_url
  end
end
