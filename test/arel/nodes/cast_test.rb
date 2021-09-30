# # frozen_string_literal: true
#
# require "./test/test_helper"
#
# module Arel
#   module Nodes
#     describe Cast do
#       attr_reader :left, :right
#
#       def instance
#         Cast.new(@left, @right)
#       end
#
#       before do
#         @left = 1
#         @right = "integer"
#       end
#
#       describe "#to_sql" do
#         def to_sql
#           instance.to_sql
#         end
#
#         it "returns the correct sql snippet" do
#           assert_equal("CAST(1 AS integer)", to_sql)
#         end
#       end
#
#       describe "#to_arel_sql" do
#         def to_arel_sql
#           instance.to_arel_sql
#         end
#
#         it "returns the correct sql snippet" do
#           assert_type(Arel::SQLString, to_arel_sql)
#         end
#       end
#     end
#   end
# end
