# gem build cancancan_nested_auth.gemspec

Gem::Specification.new do |s|
  s.name = %q{cancancan_nested_auth}
  s.version = "0.0.0"
  s.date = %q{2023-08-29}
  s.authors = ["benjamin.dana.software.dev@gmail.com"]
  s.summary = %q{A Rails Service class that uses CanCan's authorization at nested associations' individual level}
  s.licenses = ['LGPL-3.0-only']
  s.files = [
    "lib/cancancan/version.rb",
    "lib/cancancan/configuration.rb",
    "lib/cancancan/services/assignment_and_authorization.rb",
    "lib/cancancan/cancancan_nested_auth.rb",
  ]
  s.require_paths = ["lib"]
  s.homepage = 'https://github.com/danabr75/cancancan_nested_auth'
  s.add_runtime_dependency 'cancancan', ['~> 3.5.0', '>= 3.5.0']
  s.add_development_dependency 'rails', ['6.1.7.3']
  s.add_development_dependency "rspec", ["~> 3.9"]
  s.add_development_dependency "listen", ["~> 3.2"]
  s.add_development_dependency "rspec-rails", ["~> 4.0"]
  s.add_development_dependency "database_cleaner", ["~> 1.8"]
  s.add_development_dependency "sqlite3", ["~> 1.4"]
  s.required_ruby_version = '> 2'
end