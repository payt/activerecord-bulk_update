# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe BulkUpsert do
    attr_reader :upserts

    describe "#upsert_records" do
      def upsert_records
        BulkUpsert.new(@model, @upserts, ignore_persisted: @ignore_persisted, unique_by: @unique_key).upsert_records
      end

      before do
        @model = FakeRecord.all
        @upserts = [FakeRecord.new(name: "1st", rank: 1, active: false), FakeRecord.new(name: "2nd")]
        @ignore_persisted = false
        @unique_key = nil
      end

      it "inserts the records when no duplicates are given" do
        assert_change(-> { FakeRecord.count }, by: 2) { upsert_records }
      end

      describe "when unique_by is given" do
        before do
          FakeRecord.create(name: "1st", rank: 1, active: true)
          @unique_key = [:name, :rank]
        end

        it "Updates one and creates one" do
          assert_change(-> { FakeRecord.count }, by: 1) { upsert_records }
        end

        it "update the active state of the duplicate" do
          assert_change(-> { FakeRecord.where(name: "1st", rank: 1).take.active }, from: true, to: false) { upsert_records }
        end

        it "updates the updated_at timestamp" do
          assert_change(-> { FakeRecord.where(name: "1st", rank: 1).take.updated_at }) { upsert_records }
        end

        it "does not update the created_at" do
          refute_change(-> { FakeRecord.where(name: "1st", rank: 1).take.created_at }) { upsert_records }
        end
      end

      describe "when no unique_by is given" do
        before do
          FakeRecord.create(name: "1st", rank: 1)
        end

        it "raises an exception" do
          assert_raises(ActiveRecord::RecordNotUnique) { upsert_records }
        end
      end

      describe "when multiple insert have the same unique key" do
        before do
          @unique_key = [:name, :rank]
          @upserts = [FakeRecord.new(name: "1st", rank: 1), FakeRecord.new(name: "1st", rank: 1)]
        end

        it "continues without trouble" do
          assert_change(-> { FakeRecord.count }, by: 1) { upsert_records }
        end
      end
    end
  end
end
