# frozen_string_literal: true

module ActiveRecord
  module Querying
    delegate(
      :bulk_create,
      :bulk_create!,
      :bulk_delete,
      :bulk_delete_all,
      :bulk_insert,
      :bulk_update,
      :bulk_update!,
      :bulk_update_all,
      :bulk_update_columns,
      :bulk_errors,
      :bulk_valid?,
      :bulk_invalid?,
      to: :all
    )
  end
end
