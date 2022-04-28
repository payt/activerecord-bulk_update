# frozen_string_literal: true

module Arel
  module Nodes
    # Adds a new type of Node that can be used to return specific columns after an insert or update.
    #
    # @example RETURNING "column1", "column2"
    class Returning < Unary
    end
  end
end
