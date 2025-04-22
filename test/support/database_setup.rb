# frozen_string_literal: true

ActiveRecord::Base.establish_connection(
  adapter:  "postgresql",
  host:     ENV["PG_HOST"] || "localhost",
  port:     ENV["PG_PORT"] || 5432,
  username: ENV["PG_USER"] || "postgres",
  password: ENV["PG_PASSWORD"] || "",
  database: "activerecord-bulk_update_test"
)

ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new(ActiveRecord::Base.connection_db_config).purge

ActiveRecord::Migration.verbose = false

ActiveRecord::Migration.create_table :fake_records, force: true do |t|
  t.string :name
  t.boolean :active
  t.integer :rank
  t.jsonb :details
  t.integer :list, array: true
  t.integer :enumerized, default: 0, null: false

  t.timestamps null: true

  t.index [:name, :rank], unique: true
end

ActiveRecord::Migration.create_table :phony_records, id: false, force: true do |t|
  t.references :fake_record
  t.string :name
  t.boolean :active

  t.index [:name, :active], unique: true
end

ActiveRecord::Migration.create_table :bogus_records, force: true do |t|
  t.string :name

  t.index :id, unique: true
  t.index [:name], unique: true
end

ActiveRecord::Migration.create_table :composite_id_records, primary_key: [:code, :number] do |t|
  t.string :code
  t.integer :number
  t.boolean :active, default: true
end

class FakeRecord < ActiveRecord::Base
  require "enumerize"

  extend Enumerize

  has_many :phony_records

  enumerize :enumerized, in: { some: 0, other: 1 }

  validates :rank, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
end

class PhonyRecord < ActiveRecord::Base
  belongs_to :fake_record
end

class BogusRecord < ActiveRecord::Base
end

class CompositeIdRecord < ActiveRecord::Base
  self.primary_key = [:code, :number]
end

class Minitest::Test
  include ::ActiveRecord::TestFixtures

  self.fixture_paths << "test/fixtures"
  fixtures :all
end

Minitest.after_run do
  ActiveRecord::Migration.drop_table(:fake_records)
end
