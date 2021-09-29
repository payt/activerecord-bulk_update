# frozen_string_literal: true

require "./tests/test_helper"

module Arel
  module Nodes
    describe Cast do
      before do
        @cast = Cast.new(@values_list, as: @as, columns: @columns)
      end

      describe "#to_sql" do
      end
    end
  end
end
