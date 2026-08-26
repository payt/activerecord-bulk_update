# frozen_string_literal: true

module ActiveRecord
  class BulkInvalid < ActiveRecordError; end

  class Relation
    # Inserts multiple validated records into the database in a single query.
    #
    # @example
    #
    # users = [User.new(name: "foo"), User.new(name: "bar")]
    # User.where(active: true).bulk_create(users)
    #
    # @param [Record] inserts The records to insert.
    # @param [Object] validate If truthy the records are validated.
    # @param [Object] ignore_persisted If truthy any persisted records are ignored.
    #
    # @see {#bulk_insert}
    #
    # @raise [ActiveRecord::ActiveRecordError] if inserts contains persisted records and ignore_persisted is false.
    # @raise [ActiveRecord::RecordNotUnique] if inserts contains duplicated records.
    # @raise [ActiveRecord::BulkInvalid] if inserts contains invalid records and validate if truthy.
    #
    # @return [Array<Record>, Relation] the given records, each carrying the state of the row that is in the
    #   database, or the unpersisted records if any of them were invalid.
    def bulk_create(*args, **kwargs)
      bulk_create!(args, **kwargs)
    rescue ActiveRecord::BulkInvalid
      args
    end

    # Inserts multiple validated records into the database in a single query.
    #
    # @raise [ActiveRecord::BulkInvalid] if one of the records was invalid.
    #
    # @see {#bulk_create}
    #
    # @return [Array<Record>, Relation] the given records, each carrying the state of the row that is in the
    #   database.
    def bulk_create!(inserts, ignore_persisted: false, validate: true)
      raise ActiveRecord::BulkInvalid, bulk_errors(inserts) if validate && bulk_invalid?(inserts)

      bulk_insert(inserts, ignore_persisted: ignore_persisted, ignore_duplicates: false)
    end

    def bulk_delete(deletes)
      BulkDelete.new(self, deletes).delete_records
    end

    def bulk_delete_all(deletes)
      BulkDelete.new(self, deletes).delete_by_filters
    end

    # Inserts multiple records into the database in a single query.
    #
    # @example
    #
    # users = [User.new(name: "foo"), User.new(name: "bar")]
    # User.where(active: true).bulk_insert(users)
    #
    # @param [Record] inserts The records to insert.
    # @param [Object] ignore_persisted If truthy any persisted records are ignored.
    # @param [Object] ignore_duplicates If truthy any duplicate records are ignored.
    # @param [Object] unique_by Uniqueness constraint to skip rows by. Required when +ignore_duplicates+ and
    #   +assign_records+ are both truthy, so a skipped row can be traced back to the record it came from.
    #   {ActiveRecord::Persistence::ClassMethods.insert_all See ActiveRecord's insert_all}
    # @param [Object] assign_records If truthy each given record is left in the state of its row in the
    #   database (costing one extra query when rows were skipped); if falsey the records are left untouched
    #   and +true+ is returned instead.
    #
    # @see {ActiveRecord::Persistence::ClassMethods.insert_all ActiveRecord's insert_all}
    #
    # @raise [ActiveRecord::ActiveRecordError] if inserts contains persisted records and ignore_persisted is false.
    # @raise [ActiveRecord::RecordNotUnique] if inserts contains duplicated records and ignore_duplicates is false.
    # @raise [ArgumentError] if +unique_by+ is given while +ignore_duplicates+ is false, or if +unique_by+ is
    #   missing while +ignore_duplicates+ and +assign_records+ are both true.
    #
    # @return [Array<Record>, Relation, true] the given records, each carrying the state of the row that is in
    #   the database, or true when assign_records is false.
    def bulk_insert(inserts, ignore_persisted: false, ignore_duplicates: true, unique_by: nil, assign_records: true)
      BulkInsert.new(
        self, inserts,
        ignore_persisted: ignore_persisted, ignore_duplicates: ignore_duplicates, unique_by: unique_by,
        assign_records: assign_records
      ).insert_records
    end

    # Inserts multiple records into the database in a single query.
    #
    # @see {.bulk_insert}
    def bulk_insert!(inserts, ignore_persisted: false, ignore_duplicates: false, unique_by: nil, assign_records: true)
      BulkInsert.new(
        self, inserts,
        ignore_persisted: ignore_persisted, ignore_duplicates: ignore_duplicates, unique_by: unique_by,
        assign_records: assign_records
      ).insert_records
    end

    def bulk_update(*args, **kwargs)
      bulk_update!(*args, **kwargs)
    rescue ActiveRecord::BulkInvalid
      false
    end

    def bulk_update!(updates, touch: true, validate: true)
      raise ActiveRecord::BulkInvalid, bulk_errors(updates) if validate && bulk_invalid?(updates)

      BulkUpdate.new(self, updates, touch: touch).update_records

      true
    end

    def bulk_update_all(updates, touch: false)
      BulkUpdate.new(self, updates, touch: touch).update_by_hash
    end

    def bulk_update_columns(updates, touch: false)
      BulkUpdate.new(self, updates, touch: touch).update_records
    end

    def bulk_upsert(upserts, ignore_persisted: false, unique_by: nil)
      BulkUpsert.new(self, upserts, ignore_persisted: ignore_persisted, unique_by: unique_by).upsert_records
    end

    def bulk_valid?(records)
      records.map(&:valid?).all?(true)
    end

    def bulk_invalid?(records)
      !bulk_valid?(records)
    end

    def bulk_errors(records)
      records.map.with_index do |record, index|
        next if record.errors.none?

        { index: index, id: record.id_in_database, errors: record.errors.details }
      end.compact
    end
  end
end
