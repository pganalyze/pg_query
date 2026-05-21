require 'bundler/gem_tasks'
require 'rake/clean'
require 'rake/extensiontask'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'open-uri'
require 'json'

LIB_PG_QUERY_TAG = '18.1.0'.freeze
LIB_PG_QUERY_SHA256SUM = '2d3486cf6a9d3955b53e66235db39d62b54216c820cd392ab66dc842c5b1316d'.freeze

Rake::ExtensionTask.new 'pg_query' do |ext|
  ext.lib_dir = 'lib/pg_query'
end

RSpec::Core::RakeTask.new
RuboCop::RakeTask.new

task spec: :compile

task default: %i[spec lint]
task test: :spec
task lint: :rubocop

CLEAN.include 'tmp/**/*'
CLEAN.include 'ext/pg_query/*.o'
CLEAN.include 'lib/pg_query/pg_query.bundle'

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
  system("cp -a #{extdir}/pg_query_ruby.c #{extdir}/ext_symbols*.sym #{extdir}/extconf.rb #{extbakdir}")

  FileUtils.rm_rf extdir

  # Reduce everything down to one directory
  system("mkdir -p #{extdir}")
  system("cp -a #{libdir}/src/* #{extdir}/")
  system("mv #{extdir}/postgres/include #{extdir}/include/postgres")
  system("mv #{extdir}/postgres/* #{extdir}/")
  system("rmdir #{extdir}/postgres")
  system("cp -a #{libdir}/pg_query.h #{extdir}/include")
  system("cp -a #{libdir}/postgres_deparse.h #{extdir}/include")
  system("cp -a #{libdir}/pg_query_scan_tokens.h #{extdir}/include")
  # Protobuf definitions
  system("protoc --proto_path=#{libdir}/protobuf --ruby_out=#{File.join(__dir__, 'lib/pg_query')} #{libdir}/protobuf/pg_query.proto")
  system("mkdir -p #{extdir}/include/protobuf")
  system("cp -a #{libdir}/protobuf/pg_query.upb*.h #{extdir}/include/protobuf")
  system("cp -a #{libdir}/protobuf/pg_query.upb_minitable.c #{extdir}/")
  # Protobuf library code (upb)
  system("mkdir -p #{extdir}/include/upb")
  system("cp -a #{libdir}/vendor/upb/upb/* #{extdir}/include/upb")
  system("cp -a #{libdir}/vendor/upb/upb.c #{extdir}/")
  system("cp -a #{libdir}/vendor/upb/third_party/utf8_range/*.{h,inc} #{extdir}/include")
  system("cp -a #{libdir}/vendor/upb/third_party/utf8_range/*.c #{extdir}/")
  # xxhash library code
  system("mkdir -p #{extdir}/include/xxhash")
  system("cp -a #{libdir}/vendor/xxhash/*.h #{extdir}/include")
  system("cp -a #{libdir}/vendor/xxhash/*.h #{extdir}/include/xxhash")
  system("cp -a #{libdir}/vendor/xxhash/*.c #{extdir}/")
  # Copy back the custom ext files
  system("cp -a #{extbakdir}/pg_query_ruby.c #{extbakdir}/ext_symbols*.sym #{extbakdir}/extconf.rb #{extdir}")
  # Generate fingerprint test data (hash and hash parts) from libpg_query's fingerprint tests
  generate_fingerprint_json(libdir, workdir, File.join(testfilesdir, 'fingerprint.json'))
end

def generate_fingerprint_json(libdir, workdir, outfile)
  system("make -C #{libdir} build") || raise('ERROR')

  helper_src = File.join(workdir, 'fingerprint_parts.c')
  helper_bin = File.join(workdir, 'fingerprint_parts')
  File.write(helper_src, <<~C)
    #include <pg_query.h>
    #include <pg_query_fingerprint.h>
    #include <stdio.h>
    #include <stdlib.h>

    int main(void)
    {
      PgQueryFingerprintResult result;
      size_t len = 0, cap = 4096, n;
      char *input = malloc(cap);
      while ((n = fread(input + len, 1, cap - len - 1, stdin)) > 0) {
        len += n;
        if (cap - len == 1) input = realloc(input, cap *= 2);
      }
      input[len] = '\\0';
      result = pg_query_fingerprint_with_opts(input, PG_QUERY_PARSE_DEFAULT, PG_QUERY_FINGERPRINT_DEFAULT, true);
      if (result.error) return 1;
      printf("%s\\n", result.fingerprint_str);
      return 0;
    }
  C
  system("cc -I#{libdir} -I#{libdir}/src -o #{helper_bin} #{helper_src} #{libdir}/libpg_query.a") || raise('ERROR')

  test_lines = File.read(File.join(libdir, 'test/fingerprint_tests.c')).lines.grep(/\A\s*"/)
  tests = test_lines.map { |line| line.strip.delete_suffix(',').undump }

  entries = tests.each_slice(2).map do |input, expected_hash|
    output = IO.popen([helper_bin], 'r+') do |io|
      io.write(input)
      io.close_write
      io.read
    end
    raise "Failed to fingerprint #{input.inspect}" unless $?.success?

    tokens_line, _, hash = output.chomp.rpartition("\n")
    raise "Unexpected fingerprint for #{input.inspect}: got #{hash}, expected #{expected_hash}" if hash != expected_hash

    parts = tokens_line.delete_prefix('[').delete_suffix(']').scan(/"(.*?)", /m).flatten
    format(%(  {\n    "input": %<input>s,\n    "expectedParts": %<parts>s,\n    "expectedHash": %<hash>s\n  }),
           input: JSON.generate(input), parts: JSON.generate(parts).gsub('","', '", "'), hash: JSON.generate(hash))
  end

  File.write(outfile, "[\n#{entries.join(",\n")}\n]\n")
end
