# frozen_string_literal: true

require "./tests/test_helper"

module ActiveRecord
  describe Querying do
    describe ".bulk_update" do
      it "returns 0" do
        assert_equal(0, FakeRecord.bulk_update({}))
      end
    end
  end
end
