# frozen_string_literal: true

class MiniTest::Test
  def assert_change(test_proc, options = {}, &block)
    if options.key?(:from) && options.key?(:to) && options[:from] == options[:to]
      raise ArgumentError, "'from' and 'to' values must differ"
    end

    before = test_proc.call
    assert_equal(options[:from], before) if options.key?(:from)
    yield
    after = test_proc.call
    assert_equal(options[:to], after) if options.key?(:to)
    assert_equal(options[:by], after - before) if options.key?(:by)
    refute_equal(before, after) # rubocop:disable Rails/RefuteMethods
  end

  def refute_change(test_proc, options = {}, &block)
    before = test_proc.call
    assert_equal(options[:from], before) if options.key?(:from)
    yield
    after = test_proc.call
    assert_equal(before, after)
  end
end
