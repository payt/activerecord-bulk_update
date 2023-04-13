# frozen_string_literal: true

module ActiveRecord
  class BulkInvalid < ActiveRecordError; end

  class Relation
    def bulk_create(*args, **kwargs)
      bulk_create!(*args, **kwargs)
    rescue ActiveRecord::BulkInvalid
      false
    end

    def bulk_create!(inserts, ignore_persisted: false, touch: true, validate: true)
      raise ActiveRecord::BulkInvalid, bulk_errors(inserts) if validate && bulk_invalid?(inserts)

      bulk_insert(inserts, ignore_persisted: ignore_persisted, touch: touch)

      true
    end

    def bulk_delete(deletes)
      BulkDelete.new(self, deletes).delete_records
    end

    def bulk_delete_all(deletes)
      BulkDelete.new(self, deletes).delete_by_filters
    end

    def bulk_insert(inserts, ignore_persisted: false, touch: false)
      BulkInsert.new(self, inserts, ignore_persisted: ignore_persisted, touch: touch).insert_records
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

    def bulk_upsert(upserts, ignore_persisted: false, touch: false, unique_by: nil)
      BulkUpsert.new(self, upserts, ignore_persisted: ignore_persisted, touch: touch,
                                    unique_by: unique_by).upsert_records
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
