# frozen_string_literal: true

module ActiveRecord
  # Builds the query to insert multiple records in a single statement.
  class BulkInsert
    attr_reader :model, :inserts, :records, :values, :ignore_persisted, :ignore_duplicates, :unique_by,
                :assign_records

    def initialize(model, inserts, ignore_persisted:, ignore_duplicates:, unique_by:, assign_records: true)
      @model = model
      @inserts = inserts
      @records = []
      @values = []
      @ignore_persisted = ignore_persisted
      @ignore_duplicates = ignore_duplicates
      @unique_by = unique_by
      @assign_records = assign_records
    end

    # @return [Array<Record>, Relation, true] the given records, each carrying the state of the row that is in
    #   the database, or true when assign_records is false.
    def insert_records
      validate_options
      extract_values_from_records

      return execute_only unless assign_records

      insert_and_assign
      inserts
    end

    private
      # Both options are checked before anything is inserted, so a caller finds out on its first run instead of
      # the first time the database happens to skip a row.
      def validate_options
        raise ArgumentError.new("do not combine unique_by and ignore_duplicates = false") if
          unique_by && !ignore_duplicates
        return unless ignore_duplicates && assign_records && unique_by.nil?

        raise ArgumentError.new(
          "pass unique_by so a skipped row can be traced back to the record it came from, or " \
          "assign_records: false when the given records do not have to reflect the database"
        )
      end

      def execute_only
        execute unless values.empty?

        true
      end

      def insert_and_assign
        return if values.empty?

        # Register the records on the current transaction to allow AR to revert changes in case of a rollback.
        records.each do |record|
          record.send(:remember_transaction_record_state)
          record.send(:add_to_transaction)
        end

        assign_returned_attributes(execute.to_a)
      end

      def execute
        if ignore_duplicates
          model.insert_all(values, returning: returning_attributes, unique_by: unique_by)
        else
          model.insert_all!(values, returning: returning_attributes)
        end
      end

      def inserting_attributes
        @inserting_attributes ||= inserts.flat_map do |record|
          if record.persisted?
            next [] if ignore_persisted
            raise ActiveRecordError, "cannot insert a persisted record"
          end

          record.changed
        end.uniq
      end

      # Nothing has to come back when the records are not going to be updated with it.
      def returning_attributes
        @returning_attributes ||= assign_records ? (database_generated_attributes + matching_key).uniq : []
      end

      def database_generated_attributes
        model.columns.select(&:default_function).map(&:name) - inserting_attributes
      end

      # `records` holds the records that ended up in `values`, in the same order, so a returned row is never
      # attributed to a record that was left out of the statement.
      def extract_values_from_records
        raise TypeError, "expected [] or ActiveRecord::Relation, got #{inserts}" unless inserts.is_a?(Array) || inserts.is_a?(Relation)

        inserts.each do |record|
          raise TypeError, "expected #{model.new}, got #{record}" unless record.is_a?(model.klass)
          raise ActiveRecordError, "cannot insert a destroyed record" if record.destroyed?

          changes = record.attributes.slice(*inserting_attributes)
          next if changes.empty?
          next if ignore_persisted && record.persisted?

          records << record
          values << changes
        end
      end

      def assign_returned_attributes(rows)
        # Without ignore_duplicates the database cannot have skipped a row, so the rows come back one per record.
        return records.zip(rows).each { |record, attributes| assign_inserted(record, attributes || {}) } if
          matching_key.empty?

        returned = rows.index_by { |row| key_for(row) }
        skipped = []

        records.zip(values).each do |record, sent|
          attributes = returned[key_for(sent)]
          attributes.nil? ? skipped << record : assign_inserted(record, attributes)
        end

        assign_existing_attributes(skipped) if skipped.any?
      end

      # ON CONFLICT DO NOTHING offers no way to return the rows that caused a conflict, so the records that were
      # skipped are given the state of the row that is in the database, in one extra query. That row is what the
      # caller has to act on: the record it built was never written.
      def assign_existing_attributes(skipped)
        existing = model.klass.unscoped
          .where(matching_key.map(&:to_sym) => skipped.map { |record| key_for(record.attributes) })
          .index_by { |row| key_for(row.attributes) }

        skipped.each do |record|
          row = existing[key_for(record.attributes)]

          # Deleted again in the meantime. Leaving it a new record beats claiming a row that is no longer there.
          assign_existing(record, row) if row
        end
      end

      def assign_inserted(record, attributes)
        assign(record, model.where_values_hash.merge(attributes), previously_new_record: true)
      end

      # No where_values_hash here: every column of the row is already present, and overlaying the scope on top
      # of it would describe a row that is not in the database.
      def assign_existing(record, row)
        assign(record, row.attributes, previously_new_record: false)
      end

      def assign(record, attributes, previously_new_record:)
        record.assign_attributes(attributes)
        record.changes_applied
        record.instance_variable_set(:@new_record, false)
        record.instance_variable_set(:@previously_new_record, previously_new_record)
      end

      # The columns that identify one of the rows being inserted, so a returned row can be paired with the
      # record it came from and a skipped one can be looked up. The conflict target is the only sound choice:
      # ON CONFLICT (target) confines a skip to that one constraint, where an untargeted ON CONFLICT skips a row
      # for whichever unique index it violates. Rows can only be skipped when duplicates are ignored.
      def matching_key
        @matching_key ||= ignore_duplicates ? unique_by_columns : []
      end

      # Mirrors ActiveRecord::InsertAll#find_unique_index_for, where unique_by names either an index or its
      # columns. Falls back to the given names, which is what Rails does for a primary key that has no unique
      # index of its own.
      def unique_by_columns
        match = Array(unique_by).map(&:to_s)
        index = model.klass.schema_cache.indexes(model.table_name).select(&:unique).find do |candidate|
          match.include?(candidate.name) || Array(candidate.columns).sort == match.sort
        end

        index ? Array(index.columns) : match
      end

      # Casting both sides through the attribute type keeps a value the database returned comparable to the one
      # that was sent. A type that does not round trip through #cast (jsonb, for one) makes a record look
      # skipped, which costs it a lookup in #assign_existing_attributes but never pairs it with the wrong row.
      def key_for(attributes)
        matching_key.map { |column| model.klass.type_for_attribute(column).cast(attributes[column]) }
      end
  end
end
