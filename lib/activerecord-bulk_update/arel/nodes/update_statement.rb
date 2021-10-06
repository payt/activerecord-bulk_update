# frozen_string_literal: true

require "arel"

module Arel
  module Nodes
    class UpdateStatement
      # New method to be able to assign a FROM clause to the update statement.
      attr_accessor :from
    end
  end
end
