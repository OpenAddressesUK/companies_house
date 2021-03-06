require 'simplecov'
SimpleCov.start

$:.unshift File.join(File.dirname(__FILE__), "..")

require 'companies_house'
require 'pry'
require 'timecop'
require 'webmock/rspec'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
