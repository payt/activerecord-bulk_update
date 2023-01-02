# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe Relation do
    before { @scope = FakeRecord.all }

    describe ".bulk_update" do
      def bulk_update
        @scope.bulk_update(@records, **@options)
      end

      before do
        @records = [fake_records(:first), fake_records(:second)]
        @options = {}
      end

      it "returns true" do
        assert_equal(true, bulk_update)
      end

      describe "when one of the records is invalid" do
        before { @records.first.rank = -1 }

        it "returns false" do
          assert_equal(false, bulk_update)
        end

        it "sets the error message on the invalid record" do
          assert_change(
            -> { @records.first.errors.added?(:rank, :greater_than_or_equal_to, value: -1, count: 1) },
            to: true
          ) { bulk_update }
        end

        describe "with validation disabled" do
          before { @options[:validate] = false }

          it "returns true" do
            assert_equal(true, bulk_update)
          end
        end
      end
    end

    describe ".bulk_update!" do
      def bulk_update!
        @scope.bulk_update!(@records, **@options)
      end

      before do
        @records = [fake_records(:first), fake_records(:second)]
        @options = {}
      end

      it "returns true" do
        assert_equal(true, bulk_update!)
      end

      describe "when one of the records is invalid" do
        before { fake_records(:first).rank = -1 }

        it "sets the error message on the invalid record and raises an exception" do
          assert_change(
            -> { @records.first.errors.added?(:rank, :greater_than_or_equal_to, value: -1, count: 1) },
            to: true
          ) { assert_raises(ActiveRecord::BulkInvalid) { bulk_update! } }
        end

        describe "with validation disabled" do
          before { @options[:validate] = false }

          it "returns true" do
            assert_equal(true, bulk_update!)
          end
        end
      end
    end

    describe ".bulk_update_all" do
      def bulk_update_all
        @scope.bulk_update_all({ { active: true } => { active: false } })
      end

      it "updates the records which match the filtering clause" do
        assert_equal(2, bulk_update_all)
      end

      describe "when a regular where clause is added" do
        before { @scope = FakeRecord.where(active: true) }

        it "updates only the records which match all filtering clauses" do
          assert_equal(2, bulk_update_all)
        end
      end

      describe "when updating through an association" do
        before { @scope = fake_records(:first).phony_records }

        it "updates only the records found through the association" do
          assert_equal(1, bulk_update_all)
        end
      end

      describe "when limiting the number of records to update" do
        before { @scope = FakeRecord.limit(1) }

        it "updates only the limited number of records" do
          assert_equal(1, bulk_update_all)
        end
      end

      describe "when the combination of filters exclude all records" do
        before { @scope = FakeRecord.where(name: "third") }

        it "updates no records" do
          assert_equal(0, bulk_update_all)
        end
      end

      describe "when updating an Array field" do
        def bulk_update_all
          @scope.bulk_update_all({ { active: true } => { list: [1, 2] } })
        end

        it "updates the records which match the filtering clause" do
          assert_equal(2, bulk_update_all)
        end

        describe "when updating multiple records" do
          def bulk_update_all
            @scope.bulk_update_all({
              { active: true } => { list: [1, 2] },
              { active: false } => { list: [1, 2, 3] }
            })
          end

          it "updates the records which match the filtering clause" do
            assert_equal(3, bulk_update_all)
          end
        end
      end

      describe "when updating an jsonb field" do
        def bulk_update_all
          @scope.bulk_update_all({ { active: true } => { details: { things: [{ number: 1 }, { number: 2 }] } } })
        end

        it "updates the records which match the filtering clause" do
          assert_equal(2, bulk_update_all)
        end

        describe "when updating multiple records" do
          def bulk_update_all
            @scope.bulk_update_all({
              { active: true } => { details: { things: [{ number: 1 }, { number: 2 }] } },
              { active: false } => { details: { things: [{ number: 1 }, { number: 2 }, { number: 3 }] } }
            })
          end

          it "updates the records which match the filtering clause" do
            assert_equal(3, bulk_update_all)
          end
        end
      end
    end
  end
end
