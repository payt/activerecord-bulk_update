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

      # MONKEYPATCH
      #
      # In order to be able to include the optional FROM statement the existing method needs to be overridden.
      def visit_Arel_Nodes_UpdateStatement(o, collector)
        o = prepare_update_statement(o)

        collector << "UPDATE "
        collector = visit o.relation, collector
        collect_nodes_for o.values, collector, " SET "
        maybe_visit o.from, collector # MONKEYPATCH
        collect_nodes_for o.wheres, collector, " WHERE ", " AND "
        collect_nodes_for o.orders, collector, " ORDER BY "
        maybe_visit o.limit, collector
      end
    end
  end
end
