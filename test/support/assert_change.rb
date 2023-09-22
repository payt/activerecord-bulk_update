# frozen_string_literal: true

class Minitest::Test
  def assert_change(test_proc, from: nil, to: nil, by: nil, &block)
    raise ArgumentError, "'from' and 'to' values must differ" if !from.nil? && from == to

    before = test_proc.call
    assert_equal(from, before) if from
    yield
    after = test_proc.call
    assert_equal(to, after) if to
    assert_equal(by, after - before) if by
    refute_equal(before, after) # rubocop:disable Rails/RefuteMethods
  end

  def refute_change(test_proc, from: nil, &block)
    before = test_proc.call
    assert_equal(from, before) if from
    yield
    after = test_proc.call
    assert_equal(before, after)
  end
end
