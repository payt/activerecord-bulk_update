# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails"

require "minitest/autorun"
require "minitest/focus"
require "pry"

require "activerecord-bulk_update"

require_relative "support/database_setup"
require_relative "support/assert_change"
