# frozen_string_literal: true

module ActiveRecord
  class Relation
    def bulk_insert(inserts)
      BulkInsert.new(self, inserts).insert_records
    end

    def bulk_update(updates)
      bulk_update!(updates)
    rescue ActiveRecord::RecordInvalid
      false
    end

    def bulk_update!(updates)
      raise ActiveRecord::RecordInvalid if updates.map(&:valid?).any?(false)

      BulkUpdate.new(self, updates).update_records

      true
    end

    def bulk_update_all(updates)
      BulkUpdate.new(self, updates).update_by_hash
    end

    def bulk_update_columns(updates)
      BulkUpdate.new(self, updates).update_records
    end
  end
end
