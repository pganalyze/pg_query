require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

Rake::ExtensionTask.new 'pg_query' do |ext|
  ext.lib_dir = 'lib/pg_query'
end

RSpec::Core::RakeTask.new
RuboCop::RakeTask.new

task spec: :compile

task default: [:lint, :spec]
task test: :spec
task lint: :rubocop

task :clean do
  FileUtils.rm_rf File.join(File.dirname(__FILE__), 'tmp/')
  FileUtils.rm_f Dir.glob(File.join(File.dirname(__FILE__), 'ext/pg_query/*.o'))
  FileUtils.rm_f File.join(File.dirname(__FILE__), 'lib/pg_query/pg_query.bundle')
end
