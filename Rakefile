# frozen_string_literal: true

require "rake/testtask"
require "active_record"

Rake::TestTask.new do |t|
  t.test_files = FileList["test/**/*_test.rb"]
end

desc "Run tests"
task default: :test

desc "Create database"
task :db_create do
  ActiveRecord::Base.establish_connection(adapter:  "postgresql",
                                          host:     "localhost",
                                          database: "postgres")
  begin
    ActiveRecord::Base.connection.create_database("activerecord-bulk_update_test")
  rescue ActiveRecord::StatementInvalid
    puts "Database already exists"
  end
end
