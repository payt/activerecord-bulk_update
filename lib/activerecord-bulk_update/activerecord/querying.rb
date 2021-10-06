# frozen_string_literal: true

require "active_record"

module ActiveRecord
  module Querying
    # New method to be able to execute the BulkUpdate directly on a model class, without any scoping.
    delegate(:bulk_update_all, :bulk_update_columns, to: :all)
  end
end
