# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe BulkInsert do
    attr_reader :inserts

    describe "#insert_records" do
      def insert_records
        BulkInsert.new(
          @model, @inserts,
          ignore_persisted: @ignore_persisted, ignore_duplicates: @ignore_duplicates, unique_by: @unique_by,
          assign_records: @assign_records
        ).insert_records
      end

      before do
        @model = FakeRecord.all
        @inserts = [FakeRecord.new(name: "1st", rank: 1), FakeRecord.new(name: "2nd", rank: 2)]
        @ignore_persisted = false
        @ignore_duplicates = false
        @unique_by = nil
        @assign_records = true
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

          it "raises without inserting anything, since a skipped row could not be traced back" do
            error = nil
            refute_change(-> { FakeRecord.count }) { error = assert_raises(::ArgumentError) { insert_records } }
            assert_match(/pass unique_by/, error.message)
          end

          describe "with unique_by given" do
            before { @unique_by = [:name, :rank] }

            it "inserts the records" do
              assert_change(-> { FakeRecord.count }, by: 1) { insert_records }
            end
          end

          describe "with assign_records disabled" do
            before { @assign_records = false }

            it "inserts the records" do
              assert_change(-> { FakeRecord.count }, by: 1) { insert_records }
            end
          end

          describe "and the duplicate records have a uniqueness constraint on the primary key column" do
            before do
              @model = BogusRecord.all
              @inserts = [BogusRecord.new(name: "Foo"), BogusRecord.new(name: "Foo")]
              @unique_by = :id
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

        describe "when unique_by identifies the conflicting record" do
          before do
            @ignore_duplicates = true
            @unique_by = [:name, :rank]
            @inserts = [FakeRecord.new(name: "first", rank: 1), FakeRecord.new(name: "new", rank: 99)]
          end

          it "assigns the existing row to the conflicting record" do
            insert_records
            assert_equal(fake_records(:first).id, @inserts[0].id)
          end

          it "assigns a newly generated id to the inserted record" do
            insert_records
            refute_equal(fake_records(:first).id, @inserts[1].id) # rubocop:disable Rails/RefuteMethods
            assert(@inserts[1].id)
          end

          it "marks the conflicting record as not previously a new record" do
            insert_records
            refute(@inserts[0].previously_new_record?) # rubocop:disable Rails/RefuteMethods
          end

          it "marks the inserted record as previously a new record" do
            insert_records
            assert(@inserts[1].previously_new_record?)
          end

          describe "and every record conflicts with an existing row" do
            before { @inserts = [FakeRecord.new(name: "first", rank: 1), FakeRecord.new(name: "second", rank: 2)] }

            it "assigns each record the state of its existing row" do
              insert_records
              assert_equal(fake_records(:first).id, @inserts[0].id)
              assert_equal(fake_records(:second).id, @inserts[1].id)
            end
          end

          describe "with a unique_by naming a primary key that has no unique index of its own" do
            before do
              @model = CompositeIdRecord.all
              @unique_by = [:code, :number]
              @inserts = [
                CompositeIdRecord.new(code: composite_id_records(:first).code, number: composite_id_records(:first).number),
                CompositeIdRecord.new(code: "new", number: 99)
              ]
            end

            it "assigns the existing row to the conflicting record" do
              insert_records
              assert_equal(composite_id_records(:first).active, @inserts[0].active)
              refute(@inserts[0].previously_new_record?) # rubocop:disable Rails/RefuteMethods
            end

            it "inserts the other record" do
              assert_change(-> { CompositeIdRecord.count }, by: 1) { insert_records }
            end
          end
        end
      end

      describe "when ignoring persisted records, given a mix of persisted and new records" do
        before do
          @ignore_persisted = true
          @inserts = [fake_records(:first), FakeRecord.new(name: "new", rank: 99)]
        end

        it "assigns the generated id to the new record, not the persisted one" do
          persisted_id = fake_records(:first).id
          insert_records
          assert_equal(persisted_id, @inserts[0].id)
          refute_nil(@inserts[1].id) # rubocop:disable Rails/RefuteMethods
          refute_equal(persisted_id, @inserts[1].id) # rubocop:disable Rails/RefuteMethods
        end
      end

      describe "when assign_records is disabled" do
        before { @assign_records = false }

        it "returns true" do
          assert_equal(true, insert_records)
        end

        it "still inserts the records" do
          assert_change(-> { FakeRecord.count }, by: 2) { insert_records }
        end

        it "leaves the records unassigned" do
          refute_change(-> { @inserts.count(&:persisted?) }, from: 0) { insert_records }
        end

        it "leaves the records new" do
          insert_records
          assert(@inserts.all?(&:new_record?))
        end

        describe "when duplicates are ignored" do
          before do
            @ignore_duplicates = true
            @inserts = [FakeRecord.new(name: "1st", rank: 1), FakeRecord.new(name: "1st", rank: 1)]
          end

          it "inserts the unique records without raising" do
            assert_change(-> { FakeRecord.count }, by: 1) { insert_records }
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
            BulkInsert.new(
              @model, @inserts,
              ignore_persisted: @ignore_persisted, ignore_duplicates: @ignore_duplicates, unique_by: @unique_by,
              assign_records: @assign_records
            ).insert_records
            raise ActiveRecord::Rollback
          end
        end

        it "does not mark the records as persisted" do
          refute_change(-> { @inserts.count(&:persisted?) }, from: 0) { insert_records }
        end

        describe "and one of the records conflicts with an existing row" do
          before do
            @ignore_duplicates = true
            @unique_by = [:name, :rank]
            @inserts = [FakeRecord.new(name: "first", rank: 1), FakeRecord.new(name: "new", rank: 99)]
          end

          it "does not mark the records as persisted" do
            refute_change(-> { @inserts.count(&:persisted?) }, from: 0) { insert_records }
          end
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
