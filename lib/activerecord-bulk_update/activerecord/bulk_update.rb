# frozen_string_literal: true

module ActiveRecord
  # New class that builds the query to update multiple records in a single statement.
  class BulkUpdate
    attr_reader :model, :updates, :values, :filtering_attributes, :updating_attributes

    delegate :arel, :arel_table, :columns_hash, :primary_key, to: :model

    def initialize(model, updates)
      @model = model
      @updates = updates
      @values = []
    end

    def update_records
      extract_values_from_records
      return updates if values.none?

      execute
      updates.each(&:changes_applied)
    end

    def update_by_hash
      extract_values_from_hash
      return 0 if values.none?

      execute
    end

    private
      def execute
        model.connection.update(update_manager, "Bulk Update").tap { model.reset }
      end

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
          values_list,
          source,
          (filtering_attributes + updating_attributes.map { |attr| "_#{attr}" }).map { |attr| source[attr] }
        )
      end

      def values_list
        values[0] = (filtering_attributes + updating_attributes).zip(values[0]).map do |attr, value|
          column = columns_hash[arel_table[attr].name]
          raise ActiveModel::UnknownAttributeError.new(model, attr) unless column

          Arel::Nodes::Cast.new(value, column.sql_type).to_arel_sql
        end

        Arel::Nodes::ValuesList.new(values)
      end

      def extract_values_from_records
        raise ActiveRecordError, "cannot bulk update a model without primary_key" unless primary_key
        raise TypeError, "expected [] or ActiveRecord::Relation, got #{updates}" unless updates.is_a?(Array) || updates.is_a?(Relation)

        @filtering_attributes = [primary_key]
        @updating_attributes = updates.flat_map do |record|
          raise TypeError, "expected #{model.new}, got #{record}" unless record.is_a?(model.klass)
          raise ActiveRecordError, "cannot update a new record" if record.new_record?
          raise ActiveRecordError, "cannot update a destroyed record" if record.destroyed?

          record.changed
        end.uniq

        updates.each do |record|
          changes = record.values_at(*updating_attributes)
          next if changes.none?

          # Taking the current value of the id allows for the updating of the primary_key.
          values << [record.id_in_database, *changes]
        end
      end

      # NOTE: expects the keys in each of the Hahes to be identical. all the same type (Symbol or String) and in order.
      def extract_values_from_hash
        raise TypeError, "expected {}, got #{updates}" unless updates.is_a?(Hash)
        return if updates.empty?

        @filtering_attributes, @updating_attributes = updates.first.then do |filter, update|
          raise TypeError, "expected {}, got #{filter}" unless filter.is_a?(Hash)
          raise TypeError, "expected {}, got #{update}" unless update.is_a?(Hash)
          raise ArgumentError, "no filtering attributes given" if filter.empty?
          raise ArgumentError, "no updating attributes given" if update.empty?

          [filter.keys, update.keys]
        end

        types = (filtering_attributes + updating_attributes).map { |attr| model.type_for_attribute(attr) }

        updates.each do |filter, update|
          raise ArgumentError, "all filtering Hashes must have the same keys" if filter.keys != filtering_attributes
          raise ArgumentError, "all updating Hashes must have the same keys" if update.keys != updating_attributes

          values <<
            filter.values_at(*filtering_attributes)
            .concat(update.values_at(*updating_attributes))
            .zip(types)
            .map { |value, type| type.cast(value) }
        end
      end
  end
end
