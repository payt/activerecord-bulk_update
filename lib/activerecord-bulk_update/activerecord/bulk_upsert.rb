# frozen_string_literal: true

module ActiveRecord
  class BulkUpsert < BulkInsert
    attr_reader :unique_by

    def initialize(model, inserts, ignore_persisted:, unique_by:)
      @model = model
      @inserts = inserts
      @values = []
      @ignore_persisted = ignore_persisted
      @unique_by = unique_by
    end

    alias_method :upsert_records, :insert_records

    private
      def execute
        model.upsert_all(values, returning: returning_attributes, unique_by: unique_by)
      end
  end
end
