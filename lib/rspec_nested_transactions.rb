# frozen_string_literal: true

require 'delegate'
require 'fiber'
require 'rspec_nested_transactions/version'
require 'rspec/core'

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

  def nested_transaction(separate_thread: true, &block)
    around &wrapped_block(&block)
    nested_transaction_contexts(separate_thread, &block)
  end

  private

  FIBERS_STACK = []

  def wrapped_block
    ->(c){ yield c, ->(*args){ c.respond_to?(:run) ? c.run : c.run_examples } }
  end

  def nested_transaction_contexts(separate_thread, &block)
    (handle_config_around separate_thread, &block; return) if ::RSpec::Core::Configuration === self
    around_all(false) do |group|
      group.children.each {|c| c.send :nested_transaction_contexts, separate_thread, &block }
      block[ group, ->(*args){ group.run_examples } ]
    end
  end

  CONFIG_AROUND_ALL_NESTED_BLOCKS = []
  CONFIG_AROUND_ALL_PROCESSED_BY_GROUP = {}
  def handle_config_around(separate_thread, store = true, prepend = false, &block)
    blocks = CONFIG_AROUND_ALL_NESTED_BLOCKS
    blocks << block if store
    around_all(prepend) do |group|
      unless CONFIG_AROUND_ALL_PROCESSED_BY_GROUP[group.name]
        CONFIG_AROUND_ALL_PROCESSED_BY_GROUP[group.name] = true
        blocks.reverse_each do |b|
          group.children.each{|c| c.send :handle_config_around, separate_thread, false, true, &b }
        end
      end
      # ActiveRecord tries to get an exclusive lock for the thread that would be owned by
      # the fiber if we don't spawn a separate thread for controlling the execution of the
      # block. To handle cases like that, we use a separate thread by default.
      if !separate_thread
        block[ group, ->(*args){ group.run_examples } ]
      else
        q1, q2 = Queue.new, Queue.new
        thread = Thread.start do
          block[ group, ->(*args) { q2 << 1; q1.pop }]
        end
        q2.pop
        group.run_examples
        q1 << 1
        thread.join
      end
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

