# frozen_string_literal: true

module ActiveRecord
  # Builds the query to insert multiple records in a single statement.
  class BulkInsert
    attr_reader :model, :inserts, :values, :ignore_persisted, :touch

    def initialize(model, inserts, ignore_persisted:, touch:)
      @model = model
      @inserts = inserts
      @values = []
      @ignore_persisted = ignore_persisted
      @touch = touch
    end

    def insert_records
      extract_values_from_records
      return inserts if values.empty?

      touch_all if touch

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
        model.insert_all!(values, returning: returning_attributes)
      end

      def inserting_attributes
        @inserting_attributes ||= inserts.flat_map do |record|
          raise TypeError, "expected #{model.new}, got #{record}" unless record.is_a?(model.klass)
          raise ActiveRecordError, "cannot insert a destroyed record" if record.destroyed?

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
          changes = record.slice(*inserting_attributes)
          next if changes.empty?
          next if ignore_persisted && record.persisted?

          values << changes
        end
      end

      def touch_all
        timestamp_attributes =
          (model.timestamp_attributes_for_create_in_model + model.timestamp_attributes_for_update_in_model).uniq

        current_times = timestamp_attributes.index_with(model.current_time_from_proper_timezone)
        values.each { |value| value.reverse_merge!(current_times) }
        @inserting_attributes.unshift(timestamp_attributes).flatten!
      end
  end
end
