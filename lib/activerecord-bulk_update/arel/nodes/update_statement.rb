# frozen_string_literal: true

module Arel
  module Nodes
    class UpdateStatement
      # New method to be able to assign a FROM clause to the update statement.
      attr_accessor :from, :returning
    end
  end
end
