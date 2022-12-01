# frozen_string_literal: true

module ActiveRecord
  # Builds the query to delete multiple records in a single statement.
  class BulkDelete
    attr_reader :model, :deletes, :filters

    delegate :arel, :arel_table, :predicate_builder, :primary_key, to: :model

    def initialize(model, deletes)
      @model = model
      @deletes = deletes
      @filters = []
    end

    def delete_records
      extract_filters_from_records
      return [] if filters.empty?

      # Register the records on the current transaction to allow AR to revert changes in case of a rollback.
      deletes.each do |record|
        record.send(:remember_transaction_record_state)
        record.send(:add_to_transaction)
        record.skip_before_commit_callbacks = true
        record.skip_commit_callbacks = true
      end

      execute

      deletes.each do |delete|
        delete.instance_variable_set(:@destroyed, true)
      end
    end

    def delete_by_filters
      extract_filters_from_array
      return 0 if filters.empty?

      execute
    end

    private
      def execute
        model.connection.delete(delete_manager, "Bulk Delete").tap { model.reset }
      end

      def delete_manager
        arel.source.left = arel_table

        stmt = Arel::DeleteManager.new
        stmt.from(arel.source)
        stmt.key = arel_table[primary_key]
        stmt.take(arel.limit)
        stmt.offset(arel.offset)
        stmt.order(*arel.orders)
        stmt.wheres = arel.constraints

        stmt.where filters
          .map { |filter| filter.map { |attr, value| predicate_builder.build(arel_table[attr], value) }.reduce(&:and) }
          .reduce(&:or)

        stmt
      end

      def extract_filters_from_records
        raise UnknownPrimaryKey, model unless primary_key

        @deletes = [deletes] if deletes.is_a?(model.klass)
        raise TypeError, "expected [] or ActiveRecord::Relation, got #{deletes}" unless deletes.is_a?(Array) || deletes.is_a?(Relation)

        ids = deletes.map do |record|
          raise TypeError, "expected #{model.new}, got #{record}" unless record.is_a?(model.klass)

          record.id_in_database
        end.compact

        @filters << { primary_key => ids }
      end

      def extract_filters_from_array
        @filters = Array.wrap(deletes).reject(&:blank?)

        raise TypeError, "expected [{}], got #{deletes}" unless filters.all?(Hash)
      end
  end
end
