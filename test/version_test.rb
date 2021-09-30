# frozen_string_literal: true

require "./test/test_helper"

module ActiveRecord
  describe BulkUpdate do
    describe "::VERSION" do
      it "matches the gemver specification" do
        assert_match(/\A\d+\.\d+\.\d+\z/, BulkUpdate::VERSION)
      end
    end
  end
end
