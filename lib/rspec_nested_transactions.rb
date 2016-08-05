# frozen_string_literal: true

require 'delegate'
require 'fiber'
require 'rspec_nested_transactions/version'

module RspecNestedTransactions
  class FiberAwareGroup < SimpleDelegator
    def run_examples
      Fiber.yield
    end

    def to_proc
      proc { run_examples }
    end

    def class
      __getobj__.class
    end
  end

  def nested_transaction(&block)
    around &wrapped_block(&block)
    nested_transaction_contexts(&block)
  end

  private

  FIBERS_STACK = []

  def wrapped_block
    ->(c){ yield c, ->(*args){ c.respond_to?(:run) ? c.run : c.run_examples } }
  end

  def nested_transaction_contexts(&block)
    (handle_config_around &block; return) if ::RSpec::Core::Configuration === self
    around_all(false) do |group|
      group.children.each {|c| c.send :nested_transaction_contexts, &block }
      block[ group, ->(*args){ group.run_examples } ]
    end
  end

  CONFIG_AROUND_ALL_NESTED_BLOCKS = []
  CONFIG_AROUND_ALL_PROCESSED_BY_GROUP = {}
  def handle_config_around(store = true, prepend = false, &block)
    blocks = CONFIG_AROUND_ALL_NESTED_BLOCKS
    blocks << block if store
    around_all(prepend) do |group|
      unless CONFIG_AROUND_ALL_PROCESSED_BY_GROUP[group.name]
        CONFIG_AROUND_ALL_PROCESSED_BY_GROUP[group.name] = true
        blocks.reverse_each do |b|
          group.children.each{|c| c.send :handle_config_around, false, true, &b }
        end
      end
      block[ group, ->(*args){group.run_examples } ]
    end
  end

  def around_all(prepend, &block)
    methods = {
      before: method(prepend ? :prepend_before : :before),
      after:  method(prepend ? :prepend_after  : :after),
    }

    methods[:before].call :all do |group|
      fiber = Fiber.new(&block)
      FIBERS_STACK << fiber
      fiber.resume(FiberAwareGroup.new(group.class))
    end

    methods[:after].call :all do
      fiber = FIBERS_STACK.pop
      fiber.resume
    end
  end
end

RSpec.configure do |c|
  # make it available to example groups:
  # c.extend overrides the original Object#extend method.
  # See discussion in https://github.com/rspec/rspec-core/issues/1031#issuecomment-22264638
  c.extend RspecNestedTransactions

  # Add config.nested_transaction{}
  c.class.prepend RspecNestedTransactions
  # or RSpec::Core::Configuration.prepend RspecNestedTransactions
end

