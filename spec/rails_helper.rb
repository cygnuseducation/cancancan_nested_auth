ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require File.expand_path('../../test/test_app/config/environment', __FILE__)
require 'rspec/rails'
require 'database_cleaner'
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

if Rails.configuration.database_configuration[Rails.env]['database'] == ':memory:'
  puts "creating sqlite in memory database"
  ActiveRecord::Base.establish_connection(Rails.env.to_sym)
  ActiveRecord::Schema.verbose = false
  load "#{Rails.root}/db/schema.rb"
end

# Load in Fixtures in Rails console (^ Run the load schema commands as well)
# require "rake"
# TestApp::Application.load_tasks
# Rake::Task['db:fixtures:load'].reenable
# Rake::Task['db:fixtures:load'].invoke

RSpec.configure do |config|
  DatabaseCleaner.strategy = :transaction
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = File.expand_path('../../test/test_app/test/fixtures', __FILE__)

  config.before(:each) do
    # Our testing deals with caching. Need to ensure we clear it.
    Rails.cache.clear
    DatabaseCleaner.start
  end
  config.after(:each) do
    DatabaseCleaner.clean
    CanCanCan::NestedAssignmentAndAuthorization.reset
  end
  config.infer_spec_type_from_file_location!
end