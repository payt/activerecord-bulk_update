# frozen_string_literal: true

require "./test/test_helper"

module Arel
  module Visitors
    describe PostgreSQL do
      describe "#visit_Arel_Nodes_Cast" do
        def visit_Arel_Nodes_Cast
          PostgreSQL
            .new(ActiveRecord::Base.connection)
            .visit_Arel_Nodes_Cast(
              Arel::Nodes::Cast.new(@value, @datatype),
              Arel::Collectors::SQLString.new
            )
        end

        before do
          @value = 1
          @datatype = "integer"
        end

        it "generates the expected sql" do
          assert_equal("CAST(1 AS integer)", visit_Arel_Nodes_Cast.value)
        end

        describe "when the given value is a String" do
          before { @value = "1" }

          it "quotes the value" do
            assert_equal("CAST('1' AS integer)", visit_Arel_Nodes_Cast.value)
          end
        end

        describe "when the given datatype is not valid" do
          before { @datatype = "integer); DROP TABLES; --" }

          it "raises an exception" do
            assert_raises(ArgumentError) { visit_Arel_Nodes_Cast }
          end
        end
      end

      describe "#visit_Arel_Nodes_UpdateStatement" do
        describe "when the relation has join sources" do
          it "aliases the target table and moves joins into a FROM clause" do
            relation = FakeRecord.joins(:phony_records).where(phony_records: { name: "first" })

            assert_equal(1, relation.update_all(active: false))
            assert_equal(false, fake_records(:first).reload.active)
            assert_equal(true, fake_records(:second).reload.active)
          end
        end
      end

      describe "#visit_Arel_Nodes_From" do
        def visit_Arel_Nodes_From
          PostgreSQL
            .new(ActiveRecord::Base.connection)
            .visit_Arel_Nodes_From(
              Arel::Nodes::From.new(@values_list, @as, @columns),
              Arel::Collectors::SQLString.new
            )
        end

        before do
          @values_list = Arel::Nodes::ValuesList.new([[1, 2], [3, 4]])
          @as = Arel::Table.new("fake_records")
          @columns = [@as["name"], @as["rank"]]
        end

        it "generates the expected sql" do
          assert_equal('FROM (VALUES (1, 2), (3, 4)) AS "fake_records" ("name", "rank")', visit_Arel_Nodes_From.value)
        end
      end
    end
  end
end
