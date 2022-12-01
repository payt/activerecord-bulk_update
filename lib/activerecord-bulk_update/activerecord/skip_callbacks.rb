# frozen_string_literal: true

module ActiveRecord
  module SkipCallbacks
    attr_accessor :skip_before_commit_callbacks, :skip_commit_callbacks

    def before_committed!(*args)
      return if skip_before_commit_callbacks

      super
    end

    def committed!(*args)
      return if skip_commit_callbacks

      super
    end
  end

  module Transactions
    prepend SkipCallbacks
  end
end
