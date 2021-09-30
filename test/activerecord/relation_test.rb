# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe Relation do
    describe ".bulk_update" do
      it "returns 0" do
        assert_equal(0, FakeRecord.where(id: 0).bulk_update({}))
      end
    end
  end
end
