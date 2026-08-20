# frozen_string_literal: true

module ActiveRecord
  class BulkUpsert < BulkInsert
    def initialize(model, inserts, ignore_persisted:, unique_by:)
      super(model, inserts, ignore_persisted: ignore_persisted, ignore_duplicates: false, unique_by: unique_by)
    end

    alias_method :upsert_records, :insert_records

    private
      # An upsert has no skipped rows to identify: ON CONFLICT DO UPDATE returns a row for every record given.
      def validate_options
      end

      def execute
        model.upsert_all(values, returning: returning_attributes, unique_by: unique_by)
      end
  end
end
