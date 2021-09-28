# frozen_string_literal: true

module ActiveRecord
  # New class that builds the query to update multiple records in a single statement.
  class BulkUpdate
    attr_reader :model, :attributes, :records

    delegate :to_sql, to: :update_manager
    delegate :arel, :arel_table, :columns_hash, :primary_key, to: :model

    def initialize(model, updates)
      @model = model

      case updates
      when Hash
        @attributes = updates.dup.each { |row| row.map(&:stringify_keys!) }
        verify_attributes
      when Array, Relation
        @records = updates if updates.all?(model.klass)
        extract_attributes_from_records if records
      end

      raise TypeError, "expected {}, [#{model.new}] or #{model.name}::ActiveRecord_Relation, got #{updates}" unless attributes
    end

    def execute
      count = 0 if attributes.all?(&:empty?)
      count ||= model.connection.update(update_manager, "Bulk Update").tap { model.reset }
      records&.each(&:changes_applied) || count
    end

    def filtering_attributes
      @filtering_attributes ||= first_row.first.keys.sort
    end

    def updating_attributes
      @updating_attributes ||= first_row.last.keys.sort
    end

    private
      def update_manager
        stmt = Arel::UpdateManager.new
        arel.source.left = arel_table
        stmt.table(arel.source)
        stmt.key = arel_table[primary_key]
        stmt.take(arel.limit)
        stmt.offset(arel.offset)
        stmt.order(*arel.orders)
        stmt.wheres = arel.constraints
        filtering_attributes.each { |attr| arel.where(source[attr].eq(arel_table[attr])) }
        stmt.set(updating_attributes.map { |attr| [arel_table[attr], source["_#{attr}"]] })
        stmt.ast.from = from
        stmt
      end

      def source
        @source ||= Arel::Table.new("source")
      end

      def from
        Arel::Nodes::From.new(
          values_list: values_list,
          as: source,
          columns: (filtering_attributes + updating_attributes.map { |attr| "_#{attr}" }).map { |attr| source[attr] }
        )
      end

      def values_list
        values = []

        values << first_row.first.slice(*filtering_attributes).to_a
          .concat(first_row.last.slice(*updating_attributes).to_a)
          .map { |attr, value| Arel::Nodes::Cast.new(value, columns_hash[arel_table[attr].name].sql_type).to_arel_sql }

        attributes.each do |idxs, vals|
          values << filtering_attributes.map { |attr| idxs.fetch(attr) } + updating_attributes.map { |attr| vals.fetch(attr) }
        end

        Arel::Nodes::ValuesList.new(values)
      end

      def first_row
        @first_row ||= attributes.first
      end

      def extract_attributes_from_records
        updating_attributes = records.flat_map(&:changed).uniq

        @attributes = records.select(&:has_changes_to_save?).map do |record|
          raise ActiveRecord::ActiveRecordError, "cannot update a new record" unless record[primary_key]

          [{ primary_key => record.public_send("#{primary_key}_was") }, record.slice(*updating_attributes)]
        end.to_h
      end

      def verify_attributes
        (filtering_attributes + updating_attributes).each do |attr|
          raise ActiveModel::UnknownAttributeError.new(model, attr) unless columns_hash[arel_table[attr].name]
        end

        return if attributes.keys.all? { |row| row.keys.sort == filtering_attributes } &&
                  attributes.values.all? { |row| row.keys.sort == updating_attributes }

        raise ArgumentError, "All objects being updated must have the same keys"
      end
  end
end
