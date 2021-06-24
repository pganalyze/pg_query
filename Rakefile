require 'bundler/gem_tasks'
require 'rake/clean'
require 'rake/extensiontask'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'open-uri'

LIB_PG_QUERY_TAG = '13-2.0.4'.freeze
LIB_PG_QUERY_SHA256SUM = 'a67ef3e3b6c9cb1297f362888d6660dac165d3b020f78d23afe4293b8ceaf190'.freeze

Rake::ExtensionTask.new 'pg_query' do |ext|
  ext.lib_dir = 'lib/pg_query'
end

RSpec::Core::RakeTask.new
RuboCop::RakeTask.new

task spec: :compile

task default: %i[spec lint]
task test: :spec
task lint: :rubocop

CLEAN << 'tmp/**/*'
CLEAN << 'ext/pg_query/*.o'
CLEAN << 'lib/pg_query/pg_query.bundle'

task :update_source do
  workdir = File.join(__dir__, 'tmp')
  libdir = File.join(workdir, 'libpg_query-' + LIB_PG_QUERY_TAG)
  filename = File.join(workdir, 'libpg_query-' + LIB_PG_QUERY_TAG + '.tar.gz')
  testfilesdir = File.join(__dir__, 'spec/files')
  extdir = File.join(__dir__, 'ext/pg_query')
  extbakdir = File.join(workdir, 'extbak')

  unless File.exist?(filename)
    system("mkdir -p #{workdir}")
    File.open(filename, 'wb') do |target_file|
      URI.open('https://codeload.github.com/pganalyze/libpg_query/tar.gz/' + LIB_PG_QUERY_TAG, 'rb') do |read_file|
        target_file.write(read_file.read)
      end
    end

    checksum = Digest::SHA256.hexdigest(File.read(filename))

    if checksum != LIB_PG_QUERY_SHA256SUM
      raise "SHA256 of #{filename} does not match: got #{checksum}, expected #{LIB_PG_QUERY_SHA256SUM}"
    end
  end

  unless Dir.exist?(libdir)
    system("tar -xzf #{filename} -C #{workdir}") || raise('ERROR')
  end

  # Backup important files from ext dir
  system("rm -fr #{extbakdir}")
  system("mkdir -p #{extbakdir}")
  system("cp -a #{extdir}/pg_query_ruby.{c,sym} #{extdir}/extconf.rb #{extbakdir}")

  FileUtils.rm_rf extdir

  # Reduce everything down to one directory
  system("mkdir -p #{extdir}")
  system("cp -a #{libdir}/src/* #{extdir}/")
  system("mv #{extdir}/postgres/* #{extdir}/")
  system("rmdir #{extdir}/postgres")
  system("cp -a #{libdir}/pg_query.h #{extdir}/include")
  # Make sure every .c file in the top-level directory is its own translation unit
  system("mv #{extdir}/*{_conds,_defs,_helper}.c #{extdir}/include")
  # Protobuf definitions
  system("protoc --proto_path=#{libdir}/protobuf --ruby_out=#{File.join(__dir__, 'lib/pg_query')} #{libdir}/protobuf/pg_query.proto")
  system("mkdir -p #{extdir}/include/protobuf")
  system("cp -a #{libdir}/protobuf/*.h #{extdir}/include/protobuf")
  system("cp -a #{libdir}/protobuf/*.c #{extdir}/")
  # Protobuf library code
  system("mkdir -p #{extdir}/include/protobuf-c")
  system("cp -a #{libdir}/vendor/protobuf-c/*.h #{extdir}/include")
  system("cp -a #{libdir}/vendor/protobuf-c/*.h #{extdir}/include/protobuf-c")
  system("cp -a #{libdir}/vendor/protobuf-c/*.c #{extdir}/")
  # xxhash library code
  system("mkdir -p #{extdir}/include/xxhash")
  system("cp -a #{libdir}/vendor/xxhash/*.h #{extdir}/include")
  system("cp -a #{libdir}/vendor/xxhash/*.h #{extdir}/include/xxhash")
  system("cp -a #{libdir}/vendor/xxhash/*.c #{extdir}/")
  # Other support files
  system("cp -a #{libdir}/testdata/* #{testfilesdir}")
  # Copy back the custom ext files
  system("cp -a #{extbakdir}/pg_query_ruby.{c,sym} #{extbakdir}/extconf.rb #{extdir}")

  # Generate JSON field name helper (workaround until https://github.com/protocolbuffers/protobuf/pull/8356 is merged)
  str = "module PgQuery\n  INTERNAL_PROTO_FIELD_NAME_TO_JSON_NAME = {\n"
  cur_type = nil
  File.read(File.join(libdir, 'protobuf/pg_query.proto')).each_line do |line|
    if line[/^message (\w+)/]
      cur_type = $1
      next
    end
    next unless line[/(repeated )?\w+ (\w+) = \d+( \[json_name="(\w+)"\])?;/]
    str += format("    [%s, :%s] => '%s',\n", cur_type, $2, $4 || $2)
  end
  str += "  }\nend\n"
  File.write(File.join(__dir__, 'lib/pg_query/json_field_names.rb'), str)
end
