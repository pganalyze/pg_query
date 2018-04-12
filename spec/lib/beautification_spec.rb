require 'spec_helper'

test_files = Hash.new(0)
test_dir = File.join(File.dirname(__FILE__), '../files/beautification')
Dir.entries( test_dir ).each do |fn|
  m = fn.match %r{^(.*)\.(sql|expected)$}
  next unless m
  test_files[m[1]] += m[2] == 'sql' ? 1 : 2;
end

full_tests = test_files.keys.select { |k| test_files[k] == 3 }.sort

RSpec.describe PgQuery, "#beautify" do
  full_tests.each do |t|
    context "test base_examples #{t}" do
      it "works ok" do
        sql_file = test_dir + "/#{t}.sql"
        expected_file = test_dir + "/#{t}.expected"
        q = PgQuery.parse(File.open(sql_file).read)
        expect(q.beautify).to eq File.open(expected_file).read.chomp
      end
    end
  end
end

