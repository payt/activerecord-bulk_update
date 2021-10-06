# frozen_string_literal: true

require "activerecord-bulk_update/activerecord/bulk_update"
require "activerecord-bulk_update/activerecord/querying"
require "activerecord-bulk_update/activerecord/relation"
require "activerecord-bulk_update/arel/nodes/cast"
require "activerecord-bulk_update/arel/nodes/from"
require "activerecord-bulk_update/arel/nodes/update_statement"
require "activerecord-bulk_update/arel/visitors/postgresql"
