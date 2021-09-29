# frozen_string_literal: true

module ActiveRecord
  # New class that builds the query to update multiple records in a single statement.
  class BulkUpdate
    attr_reader :model, :updates, :values, :filtering_attributes, :updating_attributes, :records

    delegate :to_sql, to: :update_manager
    delegate :arel, :arel_table, :columns_hash, :primary_key, to: :model

    def initialize(model, updates)
      @model = model
      @updates = updates
      @values = []
      @filtering_attributes = []
      @updating_attributes = []

      case updates
      when Hash
        extract_values_from_hash
      when Array, Relation
        @records = updates
        extract_values_from_records
      else
        raise TypeError, "expected {}, [] or ActiveRecord::Relation, got #{updates}"
      end
    end

    def execute
      return records || 0 if values.none?

      count = model.connection.update(update_manager, "Bulk Update").tap { model.reset }
      records&.each(&:changes_applied) || count
    end

    private
      def update_manager
        arel.source.left = arel_table

        stmt = Arel::UpdateManager.new
        stmt.table(arel.source)
        stmt.key = arel_table[primary_key]
        stmt.take(arel.limit)
        stmt.offset(arel.offset)
        stmt.order(*arel.orders)
        stmt.wheres = arel.constraints
        filtering_attributes.each { |attr| arel.where(arel_table[attr].eq(source[attr])) }
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

      # NOTE: the ValuesList does not know about the datatypes of the columns in the database and will therefore pass
      # the values on as they are given. It will leave some values unquoted, like integers and booleans, which can
      # result in a PG::DatatypeMismatch when, for example, given an Integer for a Varchar column. ActiveRecord would
      # cast this Integer to a String while building the sql, is that something that should be implemented here?
      def values_list
        values[0] = (filtering_attributes + updating_attributes).zip(values[0]).map do |attr, value|
          column = columns_hash[arel_table[attr].name]
          raise ActiveModel::UnknownAttributeError.new(model, attr) unless column

          Arel::Nodes::Cast.new(value, column.sql_type).to_arel_sql
        end

        Arel::Nodes::ValuesList.new(values)
      end

      def extract_values_from_records
        raise ActiveRecord::ActiveRecordError, "cannot bulk update a model without primary_key" unless primary_key

        filtering_attributes << primary_key
        @updating_attributes = records.flat_map(&:changed).uniq

        records.each do |record|
          raise TypeError, "expected #{model.new}, got #{record}" unless record.is_a?(model.klass)
          raise ActiveRecord::ActiveRecordError, "cannot update a new record" unless record.persisted?

          changes = record.values_at(*updating_attributes)
          next if changes.none?

          # Taking the old value of the primary_key allows for the updating of the primary_key.
          values << [record.public_send("#{primary_key}_was"), *changes]
        end
      end

      # NOTE: expect all keys to be of the same type, either Symbol or String, and expects them to be in the same order.
      def extract_values_from_hash
        return unless first_row = updates.first

        @filtering_attributes = first_row.first.keys
        @updating_attributes = first_row.last.keys

        return unless filtering_attributes.any? && updating_attributes.any?

        updates.each do |filter, update|
          raise ArgumentError, "all filtering Hashes must have the same keys" if filter.keys != filtering_attributes
          raise ArgumentError, "all updating Hashes must have the same keys" if update.keys != updating_attributes

          values << filter.values_at(*filtering_attributes).concat(update.values_at(*updating_attributes))
        end
      end
  end
end
