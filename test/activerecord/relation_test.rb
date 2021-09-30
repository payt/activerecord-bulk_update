# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe Relation do
    describe ".bulk_update" do
      def bulk_update
        @scope.bulk_update({ active: true } => { active: false })
      end

      before { @scope = FakeRecord.all }

      it "updates the records which match the filtering clause" do
        assert_equal(2, bulk_update)
      end

      describe "when a regular where clause is added" do
        before { @scope = FakeRecord.where(name: "first") }

        it "updates only the records which match all filtering clauses" do
          assert_equal(1, bulk_update)
        end
      end

      describe "when limiting the number of records to update" do
        before { @scope = FakeRecord.limit(1) }

        it "updates only the limited number of records" do
          assert_equal(1, bulk_update)
        end
      end

      describe "when the combination of filters exclude all records" do
        before { @scope = FakeRecord.where(name: "third") }

        it "updates no records" do
          assert_equal(0, bulk_update)
        end
      end
    end
  end
end
