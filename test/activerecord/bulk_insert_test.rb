# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe BulkInsert do
    attr_reader :inserts

    describe "#insert_records" do
      def insert_records
        BulkInsert.new(@model, @inserts, ignore_persisted: @ignore_persisted, ignore_duplicates: @ignore_duplicates, unique_by: @unique_by).insert_records
      end

      before do
        @model = FakeRecord.all
        @inserts = [FakeRecord.new(name: "1st", rank: 1), FakeRecord.new(name: "2nd", rank: 2)]
        @ignore_persisted = false
        @ignore_duplicates = false
        @unique_by = nil
      end

      it "inserts the records" do
        assert_change(-> { FakeRecord.count }, by: 2) { insert_records }
      end

      it "marks the records as persisted" do
        assert_change(-> { @inserts.count(&:persisted?) }, by: 2) { insert_records }
      end

      it "assigns the values created by the database" do
        assert_change(-> { @inserts.count(&:id?) }, by: 2) { insert_records }
      end

      it "returns the Array of records" do
        assert_equal(@inserts, insert_records)
      end

      describe "when inserting a value for an enumerized column" do
        before { @inserts = [FakeRecord.new(enumerized: :other)] }

        it "inserts the records" do
          assert_change(-> { FakeRecord.where(enumerized: 1).count }, by: 1) { insert_records }
        end
      end

      describe "when inserting duplicate records" do
        before { @inserts = [FakeRecord.new(name: "1st", rank: 1), FakeRecord.new(name: "1st", rank: 1)] }

        it "raises a exception" do
          error = assert_raises(::ActiveRecord::RecordNotUnique) { insert_records }
          assert_match(/duplicate key value violates unique constraint/, error.message)
        end

        describe "when duplicates are ignored" do
          before { @ignore_duplicates = true }

          it "inserts the records" do
            assert_change(-> { FakeRecord.count }, by: 1) { insert_records }
          end

          describe "and the duplicate records have a uniqueness constraint on the primary key column" do
            before do
              @model = BogusRecord.all
              @inserts = [BogusRecord.new(name: "Foo"), BogusRecord.new(name: "Foo")]
            end

            it "raises a exception" do
              error = assert_raises(::ActiveRecord::RecordNotUnique) { insert_records }
              assert_match(/duplicate key value violates unique constraint/, error.message)
            end

            describe "when unique_by is the name of a column" do
              before { @unique_by = :name }

              it "inserts the unique records" do
                assert_change(-> { BogusRecord.count }, by: 1) { insert_records }
              end
            end

            describe "when unique_by is the name of an index" do
              before { @unique_by = :index_bogus_records_on_name }

              it "inserts the unique records" do
                assert_change(-> { BogusRecord.count }, by: 1) { insert_records }
              end
            end
          end
        end
      end

      describe "when unique_by is passed" do
        before { @unique_by = [:id] }

        it "raises a exception" do
          error = assert_raises(::ArgumentError) { insert_records }
          assert_match(/do not combine unique_by and ignore_duplicates = false/, error.message)
        end
      end

      describe "when chained with a where values hash" do
        before { @model = FakeRecord.where(rank: 3) }

        it "inserts the records with the value from the where clause" do
          assert_change(-> { @model.count }, by: 2) { insert_records }
        end

        it "assigns the values of where clause to the returned records" do
          assert_change(-> { @inserts.count { |record| record.rank == 3 } }, by: 2) { insert_records }
        end
      end

      describe "when chained with an association" do
        before do
          @model = fake_records(:first).phony_records
          @inserts = [PhonyRecord.new(name: "1st"), PhonyRecord.new(name: "2nd")]
        end

        it "inserts the records through the association" do
          assert_change(-> { @model.count }, by: 2) { insert_records }
        end

        it "assigns the reference to the parent object" do
          assert_change(
            -> { @inserts.count { |record| record.fake_record_id == fake_records(:first).id } },
            by: 2
          ) { insert_records }
        end
      end

      describe "when wrapped inside a transaction that is rolled back" do
        def insert_records
          ActiveRecord::Base.transaction do
            BulkInsert.new(@model, @inserts, ignore_persisted: @ignore_persisted, ignore_duplicates: @ignore_duplicates, unique_by: @unique_by).insert_records
            raise ActiveRecord::Rollback
          end
        end

        it "does not mark the records as persisted" do
          refute_change(-> { @inserts.count(&:persisted?) }, from: 0) { insert_records }
        end
      end

      #
      # Scenarios in which nothing happens
      #

      describe "when given an empty Array" do
        before { @inserts = [] }

        it "returns the Array" do
          assert_equal(@inserts, insert_records)
        end
      end

      describe "when given only records without changes" do
        before { @inserts = [FakeRecord.new] }

        it "returns the Array" do
          assert_equal(@inserts, insert_records)
        end
      end

      describe "when given an empty ActiveRecord::Relation" do
        before { @inserts = FakeRecord.none }

        it "returns the relation" do
          assert_equal(@inserts, insert_records)
        end
      end

      #
      # Scenarios in which an exception is raised
      #

      describe "when given a record from a different model" do
        before { @inserts = [PhonyRecord.new] }

        it "raises a exception" do
          error = assert_raises(::TypeError) { insert_records }
          assert_match(/\Aexpected #<FakeRecord:.+, got #<PhonyRecord:.+>\z/, error.message)
        end
      end

      describe "when given an persisted record" do
        before { @inserts = [fake_records(:first)] }

        it "raises a exception" do
          error = assert_raises(::ActiveRecord::ActiveRecordError) { insert_records }
          assert_equal("cannot insert a persisted record", error.message)
        end
      end

      describe "when given an destroyed record" do
        before { @inserts = [fake_records(:first).tap(&:destroy!)] }

        it "raises a exception" do
          error = assert_raises(::ActiveRecord::ActiveRecordError) { insert_records }
          assert_equal("cannot insert a destroyed record", error.message)
        end
      end

      describe "when given an Array of invalid datatypes" do
        before { @inserts = [Integer] }

        it "raises a exception" do
          error = assert_raises(::TypeError) { insert_records }
          assert_match(/\Aexpected #<FakeRecord:.+, got Integer\z/, error.message)
        end
      end

      describe "when given an invalid datatype" do
        before { @inserts = Integer }

        it "raises a exception" do
          error = assert_raises(::TypeError) { insert_records }
          assert_equal("expected [] or ActiveRecord::Relation, got Integer", error.message)
        end
      end
    end
  end
end
