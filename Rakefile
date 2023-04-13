# frozen_string_literal: true

require "rake/testtask"
require "active_record"

Rake::TestTask.new do |t|
  t.test_files = FileList["test/**/*_test.rb"]
end

desc "Run tests"
task default: :test
