# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe BulkUpdate do
    describe "#execute" do
      attr_reader :updates

      def execute
        BulkUpdate.new(@model, @updates).execute
      end

      before { @model = FakeRecord.all }

      describe "when given activerecord instances with unpersisted changes" do
        before do
          first = FakeRecord.find_by!(name: "first").tap { |record| record.name = "new" }
          fake_records(:second).active = false
          fake_records(:third).rank = 4

          @updates = [first, fake_records(:second), fake_records(:third)]
        end

        it "updates the first record" do
          assert_change(-> { fake_records(:first).reload.name }, to: "new") { execute }
        end

        it "updates the second record" do
          assert_change(-> { FakeRecord.find_by!(name: "second").active }, from: true, to: false) { execute }
        end

        it "updates the third record" do
          assert_change(-> { FakeRecord.find_by!(name: "third").rank }, from: 3, to: 4) { execute }
        end

        it "marks all changes as persisted" do
          assert_change(-> { @updates.count(&:has_changes_to_save?) }, from: 3, to: 0) { execute }
        end

        it "returns the Array of records" do
          assert_equal(@updates, execute)
        end
      end

      describe "when given a Hash with multiple updates to execute" do
        before do
          @updates = {
            { name: "first" } => { name: "new", active: true, rank: 1 },
            { name: "second" } => { name: "second", active: false, rank: 2 },
            { name: "third" } => { name: "third", active: false, rank: 4 }
          }
        end

        it "updates the first record" do
          assert_change(-> { fake_records(:first).reload.name }, to: "new") { execute }
        end

        it "updates the second record" do
          assert_change(-> { FakeRecord.find_by!(name: "second").active }, from: true, to: false) { execute }
        end

        it "updates the third record" do
          assert_change(-> { FakeRecord.find_by!(name: "third").rank }, from: 3, to: 4) { execute }
        end

        it "returns the number of updated records" do
          assert_equal(3, execute)
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
          assert_change(-> { fake_records(:first).reload.rank }, from: 1, to: -1) { execute }
        end

        it "does not update the second record since the `active` filter does match its state in the db" do
          refute_change(-> { fake_records(:second).reload.rank }, from: 2) { execute }
        end

        it "updates the third record" do
          assert_change(-> { fake_records(:third).reload.rank }, from: 3, to: -3) { execute }
        end

        it "returns the number of updated records" do
          assert_equal(2, execute)
        end
      end

      #
      # Scenarios in which nothing will happen
      #

      describe "when given a record without changes" do
        before { @updates = [fake_records(:first)] }

        it "returns the Array" do
          assert_equal(@updates, execute)
        end
      end

      describe "when given an empty Hash" do
        before { @updates = {} }

        it "returns 0" do
          assert_equal(0, execute)
        end
      end

      describe "when given an Hash of empty Hashes" do
        before { @updates = { {} => {} } }

        it "returns 0" do
          assert_equal(0, execute)
        end
      end

      describe "when given an Hash without columns to update" do
        before { @updates = { { name: "first" } => {} } }

        it "returns 0" do
          assert_equal(0, execute)
        end
      end

      describe "when given an Hash without columns to select records by" do
        before { @updates = { {} => { name: "first" } } }

        it "returns 0" do
          assert_equal(0, execute)
        end
      end

      describe "when given an empty Array" do
        before { @updates = [] }

        it "returns the Array" do
          assert_equal(@updates, execute)
        end
      end

      describe "when given an empty ActiveRecord::Relation" do
        before { @updates = FakeRecord.none }

        it "returns the relation" do
          assert_equal(@updates, execute)
        end
      end

      #
      # Scenarios in which an exceptin is raised
      #

      describe "when given different number of filtering columns" do
        before do
          @updates = {
            { name: "first" } => { name: "new" },
            { name: "second", rank: 2 } => { name: "new2" },
          }
        end

        it "raises a ArgumentError" do
          assert_raises(::ArgumentError, "all filtering Hashes must have the same keys") { execute }
        end
      end

      describe "when given different number of updating columns" do
        before do
          @updates = {
            { name: "first" } => { name: "new" },
            { name: "second" } => { name: "new2", rank: 2 },
          }
        end

        it "raises a ArgumentError" do
          assert_raises(::ArgumentError, "all updating Hashes must have the same keys") { execute }
        end
      end

      describe "when given a filtering column that does not exist" do
        before { @updates = { { names: "first" } => { name: "new" } } }

        it "raises a ActiveModel::UnknownAttributeError" do
          assert_raises(
            ::ActiveModel::UnknownAttributeError,
            "unknown attribute 'names' for FakeRecord::ActiveRecord_Relation."
          ) { execute }
        end
      end

      describe "when given a updating column that does not exist" do
        before { @updates = { { name: "first" } => { names: "new" } } }

        it "raises a ActiveModel::UnknownAttributeError" do
          assert_raises(
            ::ActiveModel::UnknownAttributeError,
            "unknown attribute 'names' for FakeRecord::ActiveRecord_Relation."
          ) { execute }
        end
      end

      describe "when given a record from a different model" do
        before { @updates = [PhonyRecord.new] }

        it "raises a ActiveRecord::ActiveRecordError" do
          error = assert_raises(::TypeError) { execute }
          assert_match(/\Aexpected #<FakeRecord:.+, got #<PhonyRecord:.+>\z/, error.message)
        end
      end

      describe "when given a record from a model that does not have a primary_key" do
        before do
          @model = PhonyRecord.all
          @updates = [PhonyRecord.new]
        end

        it "raises a ActiveRecord::ActiveRecordError" do
          assert_raises(::ActiveRecord::ActiveRecordError, "cannot bulk update a model without primary_key") { execute }
        end
      end

      describe "when given an unpersisted record" do
        before { @updates = [FakeRecord.new] }

        it "raises a ActiveRecord::ActiveRecordError" do
          assert_raises(::ActiveRecord::ActiveRecordError, "cannot update a new record") { execute }
        end
      end

      describe "when given an invalid datatype" do
        before { @updates = Integer }

        it "raises a TypeError" do
          assert_raises(::TypeError, "expected {}, [] or ActiveRecord::Relation, got Integer") { execute }
        end
      end
    end
  end
end
