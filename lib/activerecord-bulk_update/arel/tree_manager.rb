# frozen_string_literal: true

module Arel
  class TreeManager
    def from(*expr)
      @ast.from = expr
    end

    def returning(*expr)
      @ast.returning = expr
    end
  end
end
