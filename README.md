# RSpec Nested Transactions

Creating the same records in the database for every single test in a group can slow down your
suite. This is a common approach when using factories rather than fixtures loaded in suite
initialization. I much prefer factories over fixtures but for a long time I employ a technique
that enable a test suite to perform as well as using fixtures (or better if you're running
just a few tests from the suite) and read as good as you are used to when using factories.

Some databases, like PostgreSQL, allow transaction savepoints. That means it's possible to
run inner transactions inside an outer transaction to put in simple words.

So, if you were able to create a set of records in a before(:all) context and rollback those
changes once the context is finished, then there would no need to recreate those records for
each example in the context. If you also run each example in an inner transaction, that
means the examples will be still isolated from each other with regards to the database state.

RSpec doesn't allow one to run an `around` hook that would include contexts besides examples.

[Myron Marston wrote an article explaining how to use Ruby Fibers to implement around(:all)
on RSpec](http://myronmars.to/n/dev-blog/2012/03/building-an-around-hook-using-fibers). It's
an interesting idea and I used the concept to implement this feature.

# Requirements

The specs for this project will only run on Ruby 2.3 and above due to the `<<~` heredoc usage,
but I suspect it works on any Ruby >= 2.0 (due to `prepend` usage).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rspec_nested_transactions'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rspec_nested_transactions

## Usage

```ruby
RSpec.configure do |c|
  c.nested_transaction do |example_or_group, run|
    (run[]; next) unless example_or_group.metadata[:db] # or delete this line if you don't care
    # With Sequel and PostgreSQL:
    DB.transaction(savepoint: true, rollback: :always, &run)

    # Alternatively:
    # conditionally issue a "BEGIN" or "SAVEPOINT #{dynamic_savepoint_name}"
    # run[]
    # conditionally issue a "ROLLBACK" or "ROLLBACK TO SAVEPOINT #{dynamic_savepoint_name}"
  end
end
```

After that every context and example will be enclosed in a (inner) transaction. No need for
DatabaseCleaner (rolling back transactions are usually faster than truncate).

`nested_transaction` can also be called from inside `describe`/`context` groups just like
`around`:

```ruby
RSpec.describe "Some Feature" do
  nested_transaction do |example_or_group, run|
    # do something and call run[] ( or run.call/run.(), your call )
  end
end
```

## Is it "production" safe?

Well, I've been using this technique since 2013 using [my fork of rspec_around_all](https://github.com/rosenfeld/rspec_around_all/tree/config_around).

Actually I've been using it for much longer, but using some monkey patches around Sequel, before
I read Myron's post. However, that code from 2013 is used to this date without changes so I
consider it to be stable. That's why I decided to clean it up by removing the parts I didn't
need, used a separate methods (instead of reusing `around`) and improved the specs to be clearer.
As a result they now require Ruby 2.3 to run. Also, it now uses `prepend` rather than
`Object.instance_method(:extend).bind(c).call`, which means it now requires Ruby >= 2.

I never had problems with my test database becoming inconsistents during all those years.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to
run the tests. You can also run `bin/console` for an interactive prompt that will allow you to
experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new
version, update the version number in `version.rb`, and then run `bundle exec rake release`,
which will create a git tag for the version, push git commits and tags, and push the `.gem`
file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome [on GitHub](https://github.com/rosenfeld/rspec_nested_transactions).


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

