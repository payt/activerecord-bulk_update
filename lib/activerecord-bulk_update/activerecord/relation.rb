# frozen_string_literal: true

module ActiveRecord
  class Relation
    def bulk_create(*args)
      bulk_create!(*args)
    rescue ActiveRecord::RecordInvalid
      false
    end

    def bulk_create!(inserts, ignore_persisted: false, touch: true, validate: true)
      raise ActiveRecord::RecordInvalid if validate && inserts.map(&:valid?).any?(false)

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

    def bulk_update(*args)
      bulk_update!(*args)
    rescue ActiveRecord::RecordInvalid
      false
    end

    def bulk_update!(updates, touch: true, validate: true)
      raise ActiveRecord::RecordInvalid if validate && updates.map(&:valid?).any?(false)

      BulkUpdate.new(self, updates, touch: touch).update_records

      true
    end

    def bulk_update_all(updates, touch: false)
      BulkUpdate.new(self, updates, touch: touch).update_by_hash
    end

    def bulk_update_columns(updates, touch: false)
      BulkUpdate.new(self, updates, touch: touch).update_records
    end
  end
end
