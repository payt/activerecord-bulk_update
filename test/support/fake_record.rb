# frozen_string_literal: true

ActiveRecord::Base.establish_connection(
  adapter:  "postgresql",
  host:     "localhost",
  database: "activerecord-bulk_update_test"
)

ActiveRecord::Migration.verbose = false

ActiveRecord::Migration.create_table(:fake_records, force: true) do |t|
  t.string :name
  t.boolean :active
  t.integer :rank
  t.jsonb :details
  t.integer :list, array: true

  t.timestamps null: true
end

ActiveRecord::Migration.create_table(:phony_records, id: false, force: true) do |t|
  t.references :fake_record
  t.string :name
  t.boolean :active
end

class FakeRecord < ActiveRecord::Base
  has_many :phony_records

  validates :rank, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
end

class PhonyRecord < ActiveRecord::Base
  belongs_to :fake_record
end

class MiniTest::Test
  include ::ActiveRecord::TestFixtures

  self.fixture_path = "test/fixtures"
  fixtures :all
end

Minitest.after_run do
  ActiveRecord::Migration.drop_table(:fake_records)
end
