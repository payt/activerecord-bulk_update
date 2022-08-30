# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe BulkSave do
    describe "#save_records" do
      def save_records
        BulkSave.new(@model, @saves, touch: @touch, validate: @validate).save_records
      end

      before do
        @model = FakeRecord.all
        @touch = true
        @validate = true
      end

      describe "when given activerecord instances with unpersisted changes" do
        before do
          first = FakeRecord.find_by!(name: "first").tap { |record| record.name = "new" }
          fake_records(:second).mark_for_destruction
          fake_records(:third).phony_records.new(name: "asdf")
          fake_records(:third).phony_records.new(name: "fdsa")
          fourth = FakeRecord.new(name: "fourth")

          @saves = [first, fake_records(:second), fake_records(:third), fourth]
        end

        it "updates the first record" do
          assert_change(-> { fake_records(:first).reload.name }, to: "new") { save_records }
        end

        it "deletes the second record" do
          assert_change(-> { FakeRecord.exists?(name: "second") }, from: true, to: false) { save_records }
        end

        it "creates the new associations for the third record" do
          assert_change(-> { fake_records(:third).phony_records.count }, from: 0, to: 2) { save_records }
        end

        it "creates the fourth record" do
          assert_change(-> { FakeRecord.exists?(name: "fourth") }, from: false, to: true) { save_records }
        end

        it "touches the updated_at" do
          assert_change(-> { fake_records(:first).reload.updated_at }) { save_records }
        end

        it "returns the Array of records" do
          assert_equal(@saves, save_records)
        end

        describe "when setting touch to false" do
          before { @touch = false }

          it "does not touch the updated_at" do
            refute_change(-> { fake_records(:first).reload.updated_at }) { save_records }
          end
        end
      end

      #
      # Scenarios in which nothing happens
      #

      describe "when given an empty Array" do
        before { @saves = [] }

        it "returns the Array" do
          assert_equal(@saves, save_records)
        end
      end

      describe "when given only records without changes" do
        before { @saves = [fake_records(:first), fake_records(:third)] }

        it "returns the Array" do
          assert_equal(@saves, save_records)
        end
      end

      describe "when given an empty ActiveRecord::Relation" do
        before { @saves = FakeRecord.none }

        it "returns the relation" do
          assert_equal(@saves, save_records)
        end
      end

      #
      # Scenarios in which an exception is raised
      #

      describe "when given an destroyed record" do
        before { @saves = [fake_records(:first).tap(&:destroy!)] }

        it "raises an exception" do
          error = assert_raises(::ActiveRecord::ActiveRecordError) { save_records }
          assert_equal("cannot save a destroyed record", error.message)
        end
      end

      describe "when given an Array of invalid datatypes" do
        before { @saves = [Integer] }

        it "raises an exception" do
          error = assert_raises(::TypeError) { save_records }
          assert_equal("expected ActiveRecord::Base, got Integer", error.message)
        end
      end

      describe "when given an invalid datatype" do
        before { @saves = Integer }

        it "raises an exception" do
          error = assert_raises(::TypeError) { save_records }
          assert_equal("expected ActiveRecord::Base, got Integer", error.message)
        end
      end
    end
  end
end
