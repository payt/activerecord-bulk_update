# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe Querying do
    describe ".bulk_update" do
      it "updates all records which the filtering statements" do
        assert_equal(2, FakeRecord.bulk_update({ active: true } => { active: false }))
      end
    end
  end
end
