# frozen_string_literal: true

require "arel"

module Arel
  module Nodes
    # Adds a new type of Node that can be used when updating from a values_list
    #
    # @example CAST('value' AS datatype)
    class Cast < Node
      attr_reader :left, :right

      def initialize(left, right)
        super()
        @left = Nodes.build_quoted(left)
        @right = build_unquoted(right)
      end

      def to_arel_sql
        Arel.sql(to_sql)
      end

      private
        # The given value is expected to be a valid PostgreSQL datatype. The code is setup so the type is taken from the
        # ActiveRecord schema. Just to be sure the value is matched against a strict regexp which matches on all
        # PostgreSQL datatypes (https://www.postgresql.org/docs/13/datatype.html)
        def build_unquoted(value)
          raise ArgumentError, "'#{value}' is not allowed to remain unquoted" unless value.match?(/\A[A-z][\w,() ]+\z/)

          Arel.sql(value)
        end
    end
  end
end
