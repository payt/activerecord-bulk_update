# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe Querying do
    describe ".bulk_update_all" do
      it "updates all records which match the filtering statements" do
        assert_equal(2, FakeRecord.bulk_update_all({ active: true } => { active: false }))
      end
    end

    describe ".bulk_update_columns" do
      before do
        @records = [fake_records(:first).tap { |record| record.name = "new" }]
      end

      it "updates all records which match the filtering statements" do
        assert_equal(@records, FakeRecord.bulk_update_columns(@records))
      end
    end
  end
end
