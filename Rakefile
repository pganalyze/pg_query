require "bundler/gem_tasks"
require "rake/extensiontask"
require "rspec/core/rake_task"

Rake::ExtensionTask.new "pg_query" do |ext|
  ext.lib_dir = "lib/pg_query"
end

RSpec::Core::RakeTask.new

task spec: :compile

task default: :spec
task test: :spec