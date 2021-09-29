# frozen_string_literal: true

require "minitest/autorun"
require "pry"

require "arel"
require "active_record"
require "active_support"
require "active_support/core_ext/module/delegation"

require_relative "support/fake_record"

require "activerecord-bulk_update"
