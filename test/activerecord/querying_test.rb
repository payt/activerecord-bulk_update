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

      describe "with thouching disabled" do
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

      describe "with thouching disabled" do
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

      describe "with thouching enabled" do
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
