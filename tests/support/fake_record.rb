# frozen_string_literal: true

ActiveRecord::Base.establish_connection(
  adapter:  "postgresql",
  host:     "localhost",
  database: "activerecord-bulk_update_test"
)

ActiveRecord::Migration.verbose = false
ActiveRecord::Migration.create_table(:fake_records, force: true) do |t|
  t.string :name
end

class FakeRecord < ActiveRecord::Base
end

Minitest.after_run do
  ActiveRecord::Migration.drop_table(:fake_records)
end
