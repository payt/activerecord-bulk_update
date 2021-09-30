# frozen_string_literal: true

module Arel
  module Nodes
    # Adds a new type of Node that can be used when updating from a values_list
    #
    # @example FROM (VALUES ('value1', 'value2'), ('value3', 'value4')) AS "alias" ("column1", "column2")
    class From < Node
      attr_accessor :as, :columns, :values_list

      def initialize(values_list, as, columns)
        super()
        @values_list = values_list
        @as = as
        @columns = columns.map { |column| Arel::Nodes::UnqualifiedColumn.new(column) }
      end
    end
  end
end
