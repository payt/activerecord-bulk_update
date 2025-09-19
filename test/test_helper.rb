# frozen_string_literal: true

# Debugger
require "pry"

# Coverage
require "simplecov"
SimpleCov.start "rails"
SimpleCov.minimum_coverage 100

# Codebase
require "activerecord-bulk_update"

# Test framework
require "minitest/autorun"
require "minitest/focus"

# Test helpers
require_relative "support/database_setup"
require_relative "support/assert_change"
