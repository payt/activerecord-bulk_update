# frozen_string_literal: true

require "./tests/test_helper"

module ActiveRecord
  describe BulkUpdate do
    describe "#execute" do
      def execute
        BulkUpdate.new(FakeRecord.all, @updates).execute
      end

      before do
        @fake_record = FakeRecord.create!(name: "first")
      end

      after do
        FakeRecord.delete_all
      end

      describe "when updating an existing record" do
        before do
          @updates = { { name: "first" } => { name: "new" } }
        end

        it "updates the record" do
          assert_equal("first", @fake_record.name)
          execute
          assert_equal("new", @fake_record.reload.name)
        end

        it "returns the number of updated records" do
          assert_equal(1, execute)
        end
      end

      describe "when given an empty Hash" do
        before { @updates = {} }

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

      describe "when given an ActiveRecord::Relation" do
        before { @updates = FakeRecord.all }

        it "returns the relation" do
          assert_equal(@updates, execute)
        end
      end

      describe "when given an unpersisted record" do
        before { @updates = [FakeRecord.new] }

        it "raises a ActiveRecord::ActiveRecordError" do
          assert_raises(::ActiveRecord::ActiveRecordError) { execute }
        end
      end

      describe "when given an invalid datatype" do
        before { @updates = Integer }

        it "raises a TypeError" do
          assert_raises(::TypeError) { execute }
        end
      end
    end
  end
end
