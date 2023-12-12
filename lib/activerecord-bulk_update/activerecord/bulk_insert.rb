# frozen_string_literal: true

module ActiveRecord
  # Builds the query to insert multiple records in a single statement.
  class BulkInsert
    attr_reader :model, :inserts, :values, :ignore_persisted, :ignore_duplicates

    def initialize(model, inserts, ignore_persisted:, ignore_duplicates:)
      @model = model
      @inserts = inserts
      @values = []
      @ignore_persisted = ignore_persisted
      @ignore_duplicates = ignore_duplicates
    end

    def insert_records
      extract_values_from_records
      return inserts if values.empty?

      # Register the records on the current transaction to allow AR to revert changes in case of a rollback.
      inserts.each do |record|
        record.send(:remember_transaction_record_state)
        record.send(:add_to_transaction)
      end

      inserts.zip(execute).each do |insert, attrs|
        insert.assign_attributes(model.where_values_hash.merge(attrs || {}))
        insert.changes_applied
        insert.instance_variable_set(:@new_record, false)
        insert.instance_variable_set(:@previously_new_record, true)
      end

      inserts
    end

    private
      def execute
        if ignore_duplicates
          model.insert_all(values, returning: returning_attributes)
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

      def returning_attributes
        @returning_attributes ||= model.columns.select(&:default_function).map(&:name) - inserting_attributes
      end

      def extract_values_from_records
        raise TypeError, "expected [] or ActiveRecord::Relation, got #{inserts}" unless inserts.is_a?(Array) || inserts.is_a?(Relation)

        inserts.each do |record|
          raise TypeError, "expected #{model.new}, got #{record}" unless record.is_a?(model.klass)
          raise ActiveRecordError, "cannot insert a destroyed record" if record.destroyed?

          changes = record.attributes.slice(*inserting_attributes)
          next if changes.empty?
          next if ignore_persisted && record.persisted?

          values << changes
        end
      end
  end
end
