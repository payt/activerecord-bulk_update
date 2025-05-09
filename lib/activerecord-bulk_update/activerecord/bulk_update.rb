# frozen_string_literal: true

module ActiveRecord
  # Builds the query to update multiple records in a single statement.
  class BulkUpdate
    attr_reader :model, :touch, :updates, :filter_values, :update_values, :filter_attributes, :update_attributes

    delegate :arel, :arel_table, :columns_hash, :predicate_builder, :primary_key, to: :model

    def initialize(model, updates, touch:)
      @model = model
      @touch = touch
      @updates = updates
      @filter_values = []
      @update_values = []
    end

    def update_records
      extract_values_from_records
      return updates if update_values.empty?

      # Register the records on the current transaction to allow AR to revert changes in case of a rollback.
      updates.each do |record|
        record.send(:remember_transaction_record_state)
        record.send(:add_to_transaction)
      end

      if touch && timestamps_to_touch.any?
        touch_all
        updates.each { |record| record.assign_attributes(timestamps_to_touch)  }
      end

      execute
      updates.each(&:changes_applied)
    end

    def update_by_hash
      extract_values_from_hash
      return 0 if update_values.empty?

      touch_all if touch && timestamps_to_touch.any?
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

        if update_values.uniq.one?
          stmt.set(update_attributes.zip(update_values.first).map { |attr, value| [arel_table[attr], value] })

          if filter_attributes.many?
            arel.where(predicate_builder.build_from_hash(filter_attributes.map { arel_table[_1].name } => filter_values).reduce(:and))
          else
            arel.where(predicate_builder.build(arel_table[filter_attributes.first], filter_values.flatten))
          end
        else
          stmt.set(update_attributes.map { |attr| [arel_table[attr], source["_#{attr}"]] })
          filter_attributes.each { |attr| arel.where(arel_table[attr].eq(source[attr])) }
          stmt.ast.from = from
        end

        stmt
      end

      def source
        @source ||= Arel::Table.new("source")
      end

      def from
        Arel::Nodes::From.new(
          values_list,
          source,
          (filter_attributes + update_attributes.map { |attr| "_#{attr}" }).map { |attr| source[attr] }
        )
      end

      # @return [ValuesList]
      #
      # The first row is special since Postgresql will determine the datatype based on this row. To prevent PG from
      # making an incorrect assumption about the data types these are explicitly set on the values of the first row.
      def values_list
        Arel::Nodes::ValuesList.new(values[1..].unshift(
          (filter_attributes + update_attributes).zip(values[0]).map do |attr, value|
            Arel::Nodes::Cast.new(value, columns_hash[arel_table[attr].name].sql_type_metadata.sql_type).to_arel_sql
          end
        ))
      end

      def values
        @values ||= filter_values.map.with_index { |filter, index| [*filter, *update_values[index]] }
      end

      def extract_values_from_records
        raise UnknownPrimaryKey, model unless primary_key
        raise TypeError, "expected [] or ActiveRecord::Relation, got #{updates}" unless updates.is_a?(Array) || updates.is_a?(Relation)

        @filter_attributes = [*primary_key]
        @update_attributes = updates.flat_map do |record|
          raise TypeError, "expected #{model.new}, got #{record}" unless record.is_a?(model.klass)
          raise ActiveRecordError, "cannot update a new record" if record.new_record?
          raise ActiveRecordError, "cannot update a destroyed record" if record.destroyed?

          record.changed
        end.uniq

        updates.each do |record|
          next unless record.has_changes_to_save?

          changes = record.attributes.slice(*update_attributes).map do |name, value|
            # Using the predicate_builder allows for more complex data types like jsonb to be casted correctly.
            predicate_builder.build_bind_attribute(arel_table[name].name, value).value_for_database
          end

          # Taking the current value of the id allows for the updating of the primary_key.
          filter_values << record.id_in_database
          update_values << changes
        end
      end

      # NOTE: expects the keys in each of the Hashes to be identical. all the same type (Symbol or String) and in the same order.
      def extract_values_from_hash
        raise TypeError, "expected {}, got #{updates}" unless updates.is_a?(Hash)
        return if updates.empty?

        @filter_attributes, @update_attributes = updates.first.then do |filter, update|
          raise TypeError, "expected {}, got #{filter}" unless filter.is_a?(Hash)
          raise TypeError, "expected {}, got #{update}" unless update.is_a?(Hash)
          raise ArgumentError, "no filtering attributes given" if filter.empty?
          raise ArgumentError, "no updating attributes given" if update.empty?

          [filter.keys, update.keys]
        end

        updates.each do |filter, update|
          raise ArgumentError, "all filtering Hashes must have the same keys" if filter.keys != filter_attributes
          raise ArgumentError, "all updating Hashes must have the same keys" if update.keys != update_attributes

          filter_values << filter.map do |type, value|
            predicate_builder.build_bind_attribute(arel_table[type].name, value).value_for_database
          end
          update_values << update.map do |type, value|
            predicate_builder.build_bind_attribute(arel_table[type].name, value).value_for_database
          end
        end
      end

      def touch_all
        update_values.each { |value| value.concat(timestamps_to_touch.values) }
        @update_attributes += timestamps_to_touch.keys
      end

      def timestamps_to_touch
        @timestamps_to_touch ||=
          (model.timestamp_attributes_for_update_in_model - @update_attributes.map(&:to_s))
          .index_with { model.current_time_from_proper_timezone }
      end
  end
end
