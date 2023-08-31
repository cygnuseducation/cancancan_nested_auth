require_relative 'cancancan/configuration'
require_relative 'cancancan/services/assignment_and_authorization'
require_relative 'cancancan/version'

# include the extension 
# ActiveRecord::Base.send(:include, Serializer::Concern)

module CanCanCan
  module NestedAssignmentAndAuthorization
    # config src: http://lizabinante.com/blog/creating-a-configurable-ruby-gem/
    class << self
      attr_accessor :configuration
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.reset
      @configuration = Configuration.new
    end

    def self.configure
      yield(configuration)
    end
  end
end