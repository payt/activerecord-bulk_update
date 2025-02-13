# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe BulkUpdate do
    attr_reader :updates

    describe "#update_records" do
      def update_records
        BulkUpdate.new(@model, @updates, touch: @touch).update_records
      end

      before do
        @model = FakeRecord.all
        @touch = true
      end

      describe "when given instances with unpersisted changes" do
        before do
          first = FakeRecord.find_by!(name: "first").tap { |record| record.name = "new" }
          fake_records(:second).active = false
          fake_records(:third).rank = 4

          @updates = [first, fake_records(:second), fake_records(:third)]
        end

        it "updates the first record" do
          assert_change(-> { fake_records(:first).reload.name }, to: "new") { update_records }
        end

        it "updates the second record" do
          assert_change(-> { FakeRecord.find_by!(name: "second").active }, from: true, to: false) { update_records }
        end

        it "updates the third record" do
          assert_change(-> { FakeRecord.find_by!(name: "third").rank }, from: 3, to: 4) { update_records }
        end

        it "marks all changes as persisted" do
          assert_change(-> { @updates.count(&:has_changes_to_save?) }, from: 3, to: 0) { update_records }
        end

        it "touches the updated_at" do
          assert_change(-> { @updates.first.updated_at }) { update_records }
        end

        it "touches the updated_at column in the database" do
          assert_change(-> { fake_records(:first).reload.updated_at }) { update_records }
        end

        it "returns the Array of records" do
          assert_equal(@updates, update_records)
        end

        describe "when setting touch to false" do
          before { @touch = false }

          it "does not touch the updated_at" do
            refute_change(-> { fake_records(:first).reload.updated_at }) { update_records }
          end
        end

        describe "when the updated_at is already part of the changes on one of the records" do
          before do
            @updated_at = 30.seconds.ago.utc.round(6)
            first = FakeRecord.find_by!(name: "first").tap { |record| record.updated_at = @updated_at }

            @updates = [first, fake_records(:second)]
          end

          it "sets the updated_at to the explicitly given value" do
            assert_change(-> { fake_records(:first).reload.updated_at }, to: @updated_at) { update_records }
          end
        end

        describe "when wrapped inside a transaction that is rolled back" do
          def update_records
            ActiveRecord::Base.transaction do
              BulkUpdate.new(@model, @updates, touch: @touch).update_records
              raise ActiveRecord::Rollback
            end
          end

          it "does not mark the changes as persisted" do
            refute_change(-> { @updates.count(&:has_changes_to_save?) }, from: 3) { update_records }
          end
        end
      end

      describe "when updating the primary key" do
        before do
          @updates = [fake_records(:first).tap { |record| record.id = 0 }]
        end

        it "updates the primary key of the record" do
          assert_change(-> { FakeRecord.find_by!(name: "first").id }, to: 0) { update_records }
        end
      end

      describe "when updating a value to nil" do
        before do
          @updates = [fake_records(:first).tap { |record| record.rank = nil }]
        end

        it "clears the value in the database" do
          assert_change(-> { FakeRecord.find_by!(name: "first").rank }, to: nil) { update_records }
        end
      end

      describe "when updating all records to the same value" do
        before do
          @updates = [fake_records(:first), fake_records(:second), fake_records(:third)].each do |record|
            record.name = "asdf"
            record.active = true
          end
        end

        it "updates the records in the database" do
          assert_change(-> { FakeRecord.where(name: "asdf", active: true).count }, to: 3) { update_records }
        end
      end

      describe "when setting a value with a different datatype" do
        # Test with at least 2 records since the values of the first will be explicitly casted.
        before do
          first = FakeRecord.find_by!(name: "first").tap do |record|
            record.name = 1234
            record.details = { "asdf" => 3 }
          end
          second = FakeRecord.find_by!(name: "second").tap do |record|
            record.name = 5678
            record.details = [{ "asdf" => [{ "nested" => 3 }] }]
          end
          @updates = [first, second]
        end

        it "updates the record with value casted to the correct datatype" do
          assert_change(-> { fake_records(:second).reload.name }, to: "5678") { update_records }
        end
      end

      #
      # Scenarios in which nothing happens
      #

      describe "when given an empty Array" do
        before { @updates = [] }

        it "returns the Array" do
          assert_equal(@updates, update_records)
        end
      end

      describe "when given only records without changes" do
        before { @updates = [fake_records(:first), fake_records(:third)] }

        it "returns the Array" do
          assert_equal(@updates, update_records)
        end
      end

      describe "when given an empty ActiveRecord::Relation" do
        before { @updates = FakeRecord.none }

        it "returns the relation" do
          assert_equal(@updates, update_records)
        end
      end

      #
      # Scenarios in which an exception is raised
      #

      describe "when given a record from a different model" do
        before { @updates = [PhonyRecord.new] }

        it "raises an exception" do
          error = assert_raises(::TypeError) { update_records }
          assert_match(/\Aexpected #<FakeRecord:.+, got #<PhonyRecord:.+>\z/, error.message)
        end
      end

      describe "when given a record from a model that does not have a primary_key" do
        before do
          @model = PhonyRecord.all
          @updates = [PhonyRecord.new]
        end

        it "raises an exception" do
          assert_raises(ActiveRecord::UnknownPrimaryKey) { update_records }
        end
      end

      describe "when given an unpersisted record" do
        before { @updates = [FakeRecord.new] }

        it "raises an exception" do
          error = assert_raises(ActiveRecord::ActiveRecordError) { update_records }
          assert_equal("cannot update a new record", error.message)
        end
      end

      describe "when given an destroyed record" do
        before { @updates = [fake_records(:first).tap(&:destroy!)] }

        it "raises an exception" do
          error = assert_raises(ActiveRecord::ActiveRecordError) { update_records }
          assert_equal("cannot update a destroyed record", error.message)
        end
      end

      describe "when given an Array of invalid datatypes" do
        before { @updates = [Integer] }

        it "raises an exception" do
          error = assert_raises(::TypeError) { update_records }
          assert_match(/\Aexpected #<FakeRecord:.+, got Integer\z/, error.message)
        end
      end

      describe "when given an invalid datatype" do
        before { @updates = Integer }

        it "raises an exception" do
          error = assert_raises(::TypeError) { update_records }
          assert_equal("expected [] or ActiveRecord::Relation, got Integer", error.message)
        end
      end
    end

    describe "#update_by_hash" do
      def update_by_hash
        BulkUpdate.new(@model, @updates, touch: @touch).update_by_hash
      end

      before do
        @model = FakeRecord.all
        @touch = false
      end

      describe "when given a Hash with multiple updates" do
        before do
          @updates = {
            { name: "first" } => { name: "new", active: true, rank: 1 },
            { name: "second" } => { name: "second", active: false, rank: 2 },
            { name: "third" } => { name: "third", active: false, rank: 4 }
          }
        end

        it "updates the first record" do
          assert_change(-> { fake_records(:first).reload.name }, to: "new") { update_by_hash }
        end

        it "updates the second record" do
          assert_change(-> { FakeRecord.find_by!(name: "second").active }, from: true, to: false) { update_by_hash }
        end

        it "updates the third record" do
          assert_change(-> { FakeRecord.find_by!(name: "third").rank }, from: 3, to: 4) { update_by_hash }
        end

        it "returns the number of updated records" do
          assert_equal(3, update_by_hash)
        end

        it "does not touch the updated_at" do
          refute_change(-> { fake_records(:first).reload.updated_at }) { update_by_hash }
        end

        describe "when setting touch to true" do
          before { @touch = true }

          it "touches the updated_at" do
            assert_change(-> { fake_records(:first).reload.updated_at }) { update_by_hash }
          end
        end
      end

      describe "when given a Hash with multiple filtering columns" do
        before do
          @updates = {
            { name: "first", active: true } => { name: "new", rank: -1 },
            { name: "second", active: false } => { name: "second", rank: -2 },
            { name: "third", active: false } => { name: "third", rank: -3 }
          }
        end

        it "updates the first record" do
          assert_change(-> { fake_records(:first).reload.rank }, from: 1, to: -1) { update_by_hash }
        end

        it "does not update the second record since the `active` filter does match its state in the db" do
          refute_change(-> { fake_records(:second).reload.rank }, from: 2) { update_by_hash }
        end

        it "updates the third record" do
          assert_change(-> { fake_records(:third).reload.rank }, from: 3, to: -3) { update_by_hash }
        end

        it "returns the number of updated records" do
          assert_equal(2, update_by_hash)
        end
      end

      describe "when all records update to the same value" do
        # Test with at least 2 records
        before do
          @updates = {
            { name: "first" } => { name: 1234 },
            { name: "second" } => { name: 1234 }
          }
        end

        it "updates the first record" do
          assert_change(-> { fake_records(:first).reload.name }, to: "1234") { update_by_hash }
        end

        it "updates the second record" do
          assert_change(-> { fake_records(:second).reload.name }, to: "1234") { update_by_hash }
        end
      end

      describe "when assigning values with a different datatype" do
        # Test with at least 2 records since the values of the first will be explicitly casted.
        before do
          @updates = {
            { name: "first" } => { name: 1234 },
            { name: "second" } => { name: 5678 }
          }
        end

        it "updates the record with value casted to the correct datatype" do
          assert_change(-> { fake_records(:second).reload.name }, to: "5678") { update_by_hash }
        end
      end

      #
      # Scenarios in which nothing happens
      #

      describe "when given an empty Hash" do
        before { @updates = {} }

        it "returns 0" do
          assert_equal(0, update_by_hash)
        end
      end

      #
      # Scenarios in which an exception is raised
      #

      describe "when given an Hash without columns to select records by" do
        before { @updates = { {} => { name: "first" } } }

        it "raises an exception" do
          error = assert_raises(::ArgumentError) { update_by_hash }
          assert_equal("no filtering attributes given", error.message)
        end
      end

      describe "when given an Hash without columns to update" do
        before { @updates = { { name: "first" } => {} } }

        it "raises an exception" do
          error = assert_raises(::ArgumentError) { update_by_hash }
          assert_equal("no updating attributes given", error.message)
        end
      end

      describe "when given different number of filtering columns" do
        before do
          @updates = {
            { name: "first" } => { name: "new" },
            { name: "second", rank: 2 } => { name: "new2" },
          }
        end

        it "raises an exception" do
          error = assert_raises(::ArgumentError) { update_by_hash }
          assert_equal("all filtering Hashes must have the same keys", error.message)
        end
      end

      describe "when given different number of updating columns" do
        before do
          @updates = {
            { name: "first" } => { name: "new" },
            { name: "second" } => { name: "new2", rank: 2 },
          }
        end

        it "raises an exception" do
          error = assert_raises(::ArgumentError) { update_by_hash }
          assert_equal("all updating Hashes must have the same keys", error.message)
        end
      end

      describe "when given a filtering column that does not exist" do
        before { @updates = { { names: "first" } => { name: "new" } } }

        it "raises an exception" do
          error = assert_raises(::ActiveRecord::StatementInvalid) { update_by_hash }
          assert_match(/column fake_records.names does not exist/, error.message)
        end
      end

      describe "when given a updating column that does not exist" do
        before { @updates = { { name: "first" } => { names: "new" } } }

        it "raises an exception" do
          error = assert_raises(::ActiveRecord::StatementInvalid) { update_by_hash }
          assert_match(/column "names" of relation "fake_records" does not exist/, error.message)
        end
      end

      describe "when given an Hash containing an invalid filter" do
        before { @updates = { name: "new" } }

        it "raises an exception" do
          error = assert_raises(::TypeError, "expected {}, got name") { update_by_hash }
          assert_equal("expected {}, got name", error.message)
        end
      end

      describe "when given an invalid datatype" do
        before { @updates = Integer }

        it "raises an exception" do
          error = assert_raises(::TypeError) { update_by_hash }
          assert_equal("expected {}, got Integer", error.message)
        end
      end
    end
  end
end
