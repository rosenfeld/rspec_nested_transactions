# frozen_string_literal: true

require_relative '../lib/rspec_nested_transactions'

RSpec.configure do |c|
  c.nested_transaction do |example_or_group, run|
    (run[]; next) unless order = example_or_group.metadata[:nested_transaction_order]
    desc = example_or_group.metadata[:description_args].first
    order << "config.before #{desc}"
    run[]
    order << "config.after  #{desc}"
  end
end

RSpec.describe 'nested_transaction hook', order: :defined,
    nested_transaction_order: (order = []) do
  previous_count = 0
  context 'part 1' do
    nested_transaction do |c, run, &block|
      desc = c.metadata[:description_args].first
      order << "inner.before #{desc}"
      run[]
      order << "inner.after  #{desc}"
    end

    example('first'){ order << 'first' }
    example('second'){ order << 'second' }

    context 'inner' do
      example('inner first'){ order << 'inner first' }
      example('inner second'){ order << 'inner second' }

      example 'blocks are executed in the right order' do
        expected = <<~END
          config.before nested_transaction hook
          config.before part 1
          inner.before part 1
          config.before first
          inner.before first
          first
          inner.after  first
          config.after  first
          config.before second
          inner.before second
          second
          inner.after  second
          config.after  second
          config.before inner
          inner.before inner
          config.before inner first
          inner.before inner first
          inner first
          inner.after  inner first
          config.after  inner first
          config.before inner second
          inner.before inner second
          inner second
          inner.after  inner second
          config.after  inner second
          config.before blocks are executed in the right order
          inner.before blocks are executed in the right order
        END
        expect(order).to eq expected.split("\n")
        previous_count = order.size
      end
    end
  end

  # this context won't pass if run alone (rspec -e "part 2") since it depends on part 1
  # to run before it
  context 'part 2' do
    example 'before and after hooks order is correct' do
      expected = <<~END
        inner.after  blocks are executed in the right order
        config.after  blocks are executed in the right order
        inner.after  inner
        config.after  inner
        inner.after  part 1
        config.after  part 1
        config.before part 2
        config.before before and after hooks order is correct
      END
      expect(order[previous_count..-1]).to eq expected.split("\n")
    end
  end
end

