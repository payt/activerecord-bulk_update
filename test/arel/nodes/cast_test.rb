# frozen_string_literal: true

require "./test/test_helper"

module Arel
  module Nodes
    describe Cast do
      attr_reader :left, :right

      def instance
        Cast.new(@left, @right)
      end

      before do
        @left = 1
        @right = "integer"
      end

      describe "#to_sql" do
        def to_sql
          instance.to_sql
        end

        it "returns the correct sql snippet" do
          assert_equal("CAST(1 AS integer)", to_sql)
        end

        describe "when the value is a String" do
          before { @left = "1" }

          it "quotes the value" do
            assert_equal("CAST('1' AS integer)", to_sql)
          end
        end

        describe "when the given datatype is not valid" do
          before { @right = "integer); DROP TABLES; --" }

          it "raises an exception" do
            assert_raises(ArgumentError, "'#{@right}' is not allowed to remain unquoted") { to_sql }
          end
        end
      end

      describe "#to_arel_sql" do
        def to_arel_sql
          instance.to_arel_sql
        end

        it "returns the correct sql snippet" do
          assert_equal(Arel.sql("CAST(1 AS integer)"), to_arel_sql)
        end
      end
    end
  end
end
