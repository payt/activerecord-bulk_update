# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe Querying do
    before do
      @model = FakeRecord
      @records = [FakeRecord.new(name: "1ste"), FakeRecord.new(name: "2nd")]
      @options = {}
    end

    describe ".bulk_create" do
      def bulk_create
        @model.bulk_create(@records, **@options)
      end

      it "creates all records" do
        assert_change(-> { @model.count }, by: 2) { bulk_create }
      end

      it "sets the created_at timestamp" do
        assert_change(-> { @model.where.not(created_at: nil).count }, by: 2) { bulk_create }
      end

      it "sets the updated_at timestamp" do
        assert_change(-> { @model.where.not(updated_at: nil).count }, by: 2) { bulk_create }
      end

      it "returns true" do
        assert_equal(true, bulk_create)
      end

      describe "with touching disabled" do
        before { @options[:touch] = false }

        it "does not set the created_at timestamp" do
          refute_change(-> { @model.where.not(created_at: nil).count }) { bulk_create }
        end

        it "does not set the updated_at timestamp" do
          refute_change(-> { @model.where.not(updated_at: nil).count }) { bulk_create }
        end
      end

      describe "when one of the records is invalid" do
        before do
          @records.sample.rank = -1
        end

        it "does not create any records" do
          refute_change(-> { @model.count }) { bulk_create }
        end

        it "returns false" do
          assert_equal(false, bulk_create)
        end

        describe "with validation disabled" do
          before { @options[:validate] = false }

          it "creates all records, including the invalid record" do
            assert_change(-> { @model.count }, by: 2) { bulk_create }
          end
        end
      end
    end

    describe ".bulk_create!" do
      def bulk_create!
        @model.bulk_create!(@records, **@options)
      end

      it "creates all records" do
        assert_change(-> { @model.count }, by: 2) { bulk_create! }
      end

      it "sets the created_at timestamp" do
        assert_change(-> { @model.where.not(created_at: nil).count }, by: 2) { bulk_create! }
      end

      it "sets the updated_at timestamp" do
        assert_change(-> { @model.where.not(updated_at: nil).count }, by: 2) { bulk_create! }
      end

      it "returns true" do
        assert_equal(true, bulk_create!)
      end

      describe "with touching disabled" do
        before { @options[:touch] = false }

        it "does not set the created_at timestamp" do
          refute_change(-> { @model.where.not(created_at: nil).count }) { bulk_create! }
        end

        it "does not set the updated_at timestamp" do
          refute_change(-> { @model.where.not(updated_at: nil).count }) { bulk_create! }
        end
      end

      describe "when one of the records is invalid" do
        before do
          @records.sample.rank = -1
        end

        it "does not create any records, and raises an error" do
          refute_change(-> { @model.count }) { assert_raises(ActiveRecord::RecordInvalid) { bulk_create! } }
        end

        describe "when disabling the validation" do
          before { @options[:validate] = false }

          it "creates all records, including the invalid record" do
            assert_change(-> { @model.count }, by: 2) { bulk_create! }
          end
        end
      end
    end

    describe ".bulk_delete" do
      def bulk_delete
        @model.bulk_delete(@records)
      end

      before do
        @records = [fake_records(:first), fake_records(:second)]
      end

      it "deletes all given records" do
        assert_change(-> { @model.count }, by: -2) { bulk_delete }
      end

      it "returns the records" do
        assert_equal(@records, bulk_delete)
      end

      it "marks the records as destroyed" do
        assert_change(-> { @records.count(&:destroyed?) }, by: 2) { bulk_delete }
      end

      describe "when passing an empty list" do
        before { @records = [] }

        it "deletes nothing" do
          refute_change(-> { @model.count }) { bulk_delete }
        end
      end

      describe "when passing a single instance" do
        before { @records = fake_records(:first) }

        it "deletes the record" do
          assert_change(-> { @model.count }, by: -1) { bulk_delete }
        end
      end

      describe "when passing an incorrect type" do
        before { @records = 1 }

        it "deletes nothing and raises an error" do
          refute_change(-> { @model.count }) { assert_raises(TypeError) { bulk_delete } }
        end
      end

      describe "with a model without primary key" do
        before do
          @model = PhonyRecord
          @records = [PhonyRecord.take]
        end

        it "deletes nothing and raises an error" do
          refute_change(-> { @model.count }) { assert_raises(ActiveRecord::UnknownPrimaryKey) { bulk_delete } }
        end
      end

      describe "when wrapped inside a transaction that is rolled back" do
        def bulk_delete
          ActiveRecord::Base.transaction do
            @model.bulk_delete(@records)
            raise ActiveRecord::Rollback
          end
        end

        it "does not mark the records as destroyed" do
          refute_change(-> { @records.count(&:destroyed?) }, from: 0) { bulk_delete }
        end
      end
    end

    describe ".bulk_delete_all" do
      def bulk_delete_all
        @model.bulk_delete_all(@filters)
      end

      before { @filters = [] }

      it "deletes nothing" do
        assert_equal(0, bulk_delete_all)
      end

      describe "with different filters matching different records" do
        before { @filters = [{ active: [nil, true], rank: 1 }, { active: false, name: "third", rank: [3, 4] }, { id: 2 }] }

        it "deletes all records which match any of the filtering statements" do
          assert_equal(3, bulk_delete_all)
        end

        describe "with an additional global filter" do
          before { @model = @model.where(active: true) }

          it "deletes only the records matching the global filter plus any of the filtering statements" do
            assert_equal(2, bulk_delete_all)
          end
        end
      end

      describe "with different filters matching a single record" do
        before { @filters = [{ active: true, rank: 1 }, { id: 1 }] }

        it "deletes the one record" do
          assert_equal(1, bulk_delete_all)
        end
      end

      describe "when no records match the filtering statements" do
        before { @filters = [{ active: false, rank: 1 }, {}, { id: nil }] }

        it "deletes nothing" do
          assert_equal(0, bulk_delete_all)
        end
      end

      describe "when passing an single filter" do
        before { @filters = { active: true, rank: 1 } }

        it "deletes the one record" do
          assert_equal(1, bulk_delete_all)
        end
      end

      describe "when passing an incorrect type" do
        before { @filters = 1 }

        it "deletes nothing and raises an error" do
          refute_change(-> { @model.count }) { assert_raises(TypeError) { bulk_delete_all } }
        end
      end
    end

    describe ".bulk_insert" do
      def bulk_insert
        @model.bulk_insert(@records, **@options)
      end

      it "inserts all records" do
        assert_change(-> { @model.count }, by: 2) { bulk_insert }
      end

      it "does not set the created_at timestamp" do
        refute_change(-> { @model.where.not(created_at: nil).count }) { bulk_insert }
      end

      it "does not set the updated_at timestamp" do
        refute_change(-> { @model.where.not(updated_at: nil).count }) { bulk_insert }
      end

      it "returns the records" do
        assert_equal(@records, bulk_insert)
      end

      describe "with touching enabled" do
        before { @options[:touch] = true }

        it "sets the created_at timestamp" do
          assert_change(-> { @model.where.not(created_at: nil).count }, by: 2) { bulk_insert }
        end

        it "sets the updated_at timestamp" do
          assert_change(-> { @model.where.not(updated_at: nil).count }, by: 2) { bulk_insert }
        end
      end

      describe "when one of the records is already persisted" do
        before do
          @records << fake_records(:third)
        end

        it "raises an error" do
          error = assert_raises(ActiveRecord::ActiveRecordError) { bulk_insert }
          assert_equal("cannot insert a persisted record", error.message)
        end

        describe "with ignoring persisted records enabled" do
          before { @options[:ignore_persisted] = true }

          it "creates only the new records" do
            assert_change(-> { @model.count }, by: 2) { bulk_insert }
          end
        end
      end
    end

    describe ".bulk_update_all" do
      it "updates all records which match the filtering statements" do
        assert_equal(2, FakeRecord.bulk_update_all({ { active: true } => { active: false } }))
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
