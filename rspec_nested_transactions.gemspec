# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path('lib')
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rspec_nested_transactions/version'

Gem::Specification.new do |spec|
  spec.name          = 'rspec_nested_transactions'
  spec.version       = RspecNestedTransactions::VERSION
  spec.authors       = ['Rodrigo Rosenfeld Rosas']
  spec.email         = ['rr.rosas@gmail.com']

  spec.summary       = %q{Enable nested transactions for suites, contexts and examples. Useful to rollback DB changes in before(:all) blocks.}
  spec.homepage      = 'https://github.com/rosenfeld/rspec_nested_transactions'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^spec/}) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '>= 10'
  spec.add_runtime_dependency 'rspec', '~> 3.0'
end
