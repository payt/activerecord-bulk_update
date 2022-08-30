# frozen_string_literal: true

module ActiveRecord
  # Builds the query to save multiple records in the least amount of statements possible.
  class BulkSave
    attr_reader :model, :touch, :validate, :saves, :records

    def initialize(model, saves, touch:, validate:)
      @model = model
      @touch = touch
      @saves = saves
      @association_names = {}
      @records = []
      @validate = validate
    end

    def save_records
      extract_records(saves)
      select_records_with_changes
      raise ActiveRecord::RecordInvalid if validate && validate_records

      model.transaction do
        group_records.each do |model, delete_records, update_records, create_records|
          model.where(model.primary_key => delete_records.map(&:id_in_database)).delete_all if delete_records.any?
          BulkUpdate.new(model, update_records, touch: touch).update_records if update_records.any?
          BulkInsert.new(model, create_records, touch: touch, ignore_persisted: false).insert_records if create_records.any?
        end
      end

      saves
    end

    private
      def extract_records(saves)
        Array(saves).each do |record|
          raise TypeError, "expected ActiveRecord::Base, got #{record}" unless record.is_a?(ActiveRecord::Base)
          raise ActiveRecordError, "cannot save a destroyed record" if record.destroyed?

          next if records.include?(record) # Prevents infinite loops

          records << record

          association_names(record.class).each do |association_name|
            extract_records(record.association(association_name).target)
          end
        end
      end

      def select_records_with_changes
        records.select! { |record| record.changed? || (record.persisted? && record.marked_for_destruction?) }
      end

      def validate_records
        records.map(&:valid?).any?(false)
      end

      def group_records
        records
          .group_by(&:class)
          .map do |model, grouped|
            grouped
              .partition(&:new_record?)
              .then { |new, persisted| persisted.partition(&:marked_for_destruction?).push(new) }
              .unshift(model.all)
          end
      end

      def association_names(model)
        @association_names[model] ||= model.reflections.keys.map(&:to_sym)
      end
  end
end
