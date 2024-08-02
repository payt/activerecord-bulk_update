# frozen_string_literal: true

module ActiveRecord
  class BulkInvalid < ActiveRecordError; end

  class Relation
    def bulk_create(*args, **kwargs)
      bulk_create!(*args, **kwargs)
    rescue ActiveRecord::BulkInvalid
      false
    end

    def bulk_create!(inserts, ignore_persisted: false, validate: true)
      raise ActiveRecord::BulkInvalid, bulk_errors(inserts) if validate && bulk_invalid?(inserts)

      bulk_insert(inserts, ignore_persisted: ignore_persisted)

      true
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
    # @param [Object] unique_by Uniqueness constraint to skip rows by. Requires +ignore_duplicates+ to be
    #   falsey. {ActiveRecord::Persistence::ClassMethods.insert_all See ActiveRecord's insert_all}
    #
    # @see {ActiveRecord::Persistence::ClassMethods.insert_all ActiveRecord's insert_all}
    #
    # @raise [ActiveRecord::ActiveRecordError] if inserts contains persisted records and ignore_persisted is false.
    # @raise [ActiveRecord::RecordNotUnique] if inserts contains duplicated records and ignore_duplicates is false.
    # @raise [ArgumentError] if both +unique_by+ and +ignore_duplicates+ are provided.
    #
    # @return [ActiveRecord::Result] containing the records as they have been inserted.
    def bulk_insert(inserts, ignore_persisted: false, ignore_duplicates: true, unique_by: nil)
      BulkInsert.new(self, inserts, ignore_persisted: ignore_persisted, ignore_duplicates: ignore_duplicates, unique_by: unique_by).insert_records
    end

    # Inserts multiple records into the database in a single query.
    #
    # @see {.bulk_insert}
    def bulk_insert!(inserts, ignore_persisted: false, ignore_duplicates: false, unique_by: nil)
      BulkInsert.new(self, inserts, ignore_persisted: ignore_persisted, ignore_duplicates: ignore_duplicates, unique_by: unique_by).insert_records
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
