# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe BulkUpsert do
    attr_reader :upserts

    describe "#upsert_records" do
      def upsert_records
        BulkUpsert.new(@model, @upserts, ignore_persisted: @ignore_persisted, touch: @touch,
                       unique_by: @unique_key).upsert_records
      end

      before do
        @model = FakeRecord.all
        @upserts = [FakeRecord.new(name: "1ste", rank: 1), FakeRecord.new(name: "2nd")]
        @touch = false
        @ignore_persisted = false
        @unique_key = nil
      end

      it "inserts the records when no duplicates are given" do
        assert_change(-> { FakeRecord.count }, by: 2) { upsert_records }
      end

      describe "when unique_by is given" do
        before do
          FakeRecord.create(name: "1ste", rank: 1)
          @unique_key = [:name, :rank]
        end

        it "Updates one and creates one" do
          assert_change(-> { FakeRecord.count }, by: 1) { upsert_records }
        end

        it "Updates one and creates one" do
          assert_change(-> { FakeRecord.first.updated_at }) do
            Kernel.sleep 0.01
            upsert_records
          end
        end

        it "Do not change created_at" do
          refute_change(-> { FakeRecord.first.created_at }) { upsert_records }
        end
      end

      describe "when no unique_by is given" do
        before do
          FakeRecord.create(name: "1ste", rank: 1)
        end

        it "raises an exception" do
          assert_raises(ActiveRecord::RecordNotUnique) { upsert_records }
        end
      end
    end
  end
end
