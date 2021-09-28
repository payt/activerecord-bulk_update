# frozen_string_literal: true

module ActiveRecord
  module Querying
    # New method to be able to execute the BulkUpdate directly on a model class, without any scoping.
    delegate(:bulk_update, to: :all)
  end
end
