# frozen_string_literal: true

module ActiveRecord
  # Builds the query to insert multiple records in a single statement.
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
      return deletes if filters.empty?

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

        groupings = filters.map do |filter|
          if filter.one?
            predicate_builder.build(arel_table[filter.keys.first], filter.values.first)
          else
            Arel::Nodes::Grouping.new(Arel::Nodes::And.new(filter.map { |attr, values| predicate_builder.build(arel_table[attr], values) }))
          end
        end

        if groupings.one?
          stmt.where(groupings.first)
        else
          groupings.each_cons(2).map do |left, right|
            stmt.where(Arel::Nodes::Or.new(left, right))
          end
        end

        stmt
      end

      def extract_filters_from_records
        raise UnknownPrimaryKey, model unless primary_key
        raise TypeError, "expected [] or ActiveRecord::Relation, got #{deletes}" unless deletes.is_a?(Array) || deletes.is_a?(Relation)

        ids = deletes.map do |record|
          raise TypeError, "expected #{model.new}, got #{record}" unless record.is_a?(model.klass)

          record.id_in_database
        end.compact

        @filters << { primary_key => ids }
      end

      def extract_filters_from_array
        raise TypeError, "expected [], got #{deletes}" unless deletes.is_a?(Array)

        @filters = deletes.reject(&:blank?)
      end

      def returning_attributes
        @returning_attributes ||= model.columns.select(&:default_function).map(&:name) - inserting_attributes
      end
  end
end
