# frozen_string_literal: true

module ActiveRecord
  class Relation
    # New method to be able to execute the BulkUpdate on an existing scope.
    def bulk_update(updates)
      BulkUpdate.new(self, updates).execute
    end
  end
end
