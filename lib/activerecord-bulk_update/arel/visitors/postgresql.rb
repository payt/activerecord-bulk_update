# frozen_string_literal: true

module Arel
  module Visitors
    class PostgreSQL
      # New method to cast the Cast node to a partial sql statement.
      def visit_Arel_Nodes_Cast(o, collector)
        collector << "CAST("
        visit o.left, collector
        collector << " AS "
        visit o.right, collector
        collector << ")"
      end

      # New method to cast the From node to a partial sql statement.
      def visit_Arel_Nodes_From(o, collector)
        collector << "FROM ("
        visit o.values_list, collector
        collector << ") AS "
        visit o.as, collector
        collector << " ("
        collect_nodes_for o.columns, collector, "", ", "
        collector << ")"
      end

      # MONKEY_PATCH
      #
      # Mirrors ActiveRecord 8.1's UPDATE-with-JOIN handling (alias the target,
      # move joins into a FROM clause) and additionally emits the optional
      # `o.from` node used by bulk_update's VALUES-list updates.
      def visit_Arel_Nodes_UpdateStatement(o, collector)
        collector.retryable = false
        o = prepare_update_statement(o)

        collector << "UPDATE "

        if has_join_sources?(o)
          collector = visit o.relation.left, collector
          collect_nodes_for o.values, collector, " SET "
          collector << " FROM "
          collector = inject_join o.relation.right, collector, " "
        else
          collector = visit o.relation, collector
          collect_nodes_for o.values, collector, " SET "
        end

        maybe_visit o.from, collector # MONKEY_PATCH
        collect_nodes_for o.wheres, collector, " WHERE ", " AND "
        collect_nodes_for o.orders, collector, " ORDER BY "
        maybe_visit o.limit, collector
        maybe_visit o.comment, collector
      end
    end
  end
end
