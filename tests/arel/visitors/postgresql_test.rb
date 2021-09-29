# frozen_string_literal: true

require "./tests/test_helper"

module Arel
  module Visitors
    describe PostgreSQL do
      describe "#visit_Arel_Nodes_Cast" do
        before do
          @value = 1
          @datatype = "integer"
          @collector = Arel::Collectors::SQLString.new
          o = Arel::Nodes::Cast.new(@value, @datatype)
          connection = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new
          @visit_Arel_Nodes_Cast = PostgreSQL.new(connection).visit_Arel_Nodes_Cast(o, @collector)
        end

        it "generates the expected sql" do
          assert_equal("CAST(1 AS integer)", @visit_Arel_Nodes_Cast)
        end

        describe "when the given value is a String" do
          before { @value = "1" }

          it "quotes the value" do
            assert_equal("CAST('1' AS integer)", @visit_Arel_Nodes_Cast)
          end
        end

        describe "when the given datatype is not valid" do
          before { @datatype = "integer); DROP TABLES; --" }

          it "raises an exception" do
            assert_exception(ArgumentError, @visit_Arel_Nodes_Cast)
          end
        end
      end
    end
  end
end
