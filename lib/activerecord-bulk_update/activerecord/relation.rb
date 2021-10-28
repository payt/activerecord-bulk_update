# frozen_string_literal: true

module ActiveRecord
  class Relation
    def bulk_insert(inserts)
      BulkInsert.new(self, inserts).insert_records
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
