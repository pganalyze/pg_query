# rubocop:disable Style/GlobalVars

require 'digest'
require 'mkmf'
require 'open-uri'

LIB_PG_QUERY_TAG = '13-latest-develop-protobuf'.freeze
LIB_PG_QUERY_SHA256SUM = 'FIXFORRELEASE'.freeze

workdir = Dir.pwd
libdir = File.join(workdir, 'libpg_query-' + LIB_PG_QUERY_TAG)
gemdir = File.join(__dir__, '../..')
libfile = libdir + '/libpg_query.a'
filename = File.join(workdir, 'libpg_query-' + LIB_PG_QUERY_TAG + '.tar.gz')

unless File.exist?(filename)
  File.open(filename, 'wb') do |target_file|
    URI.open('https://codeload.github.com/lfittl/libpg_query/tar.gz/' + LIB_PG_QUERY_TAG, 'rb') do |read_file|
      target_file.write(read_file.read)
    end
  end

  checksum = Digest::SHA256.hexdigest(File.read(filename))

  #if checksum != LIB_PG_QUERY_SHA256SUM
  #  raise "SHA256 of #{filename} does not match: got #{checksum}, expected #{expected_sha256}"
  #end
end

unless Dir.exist?(libdir)
  system("tar -xzf #{filename}") || raise('ERROR')
end

unless Dir.exist?(libfile)
  # Build libpg_query (and parts of PostgreSQL)
  system(format("cd %s; %s build", libdir, ENV['MAKE'] || (RUBY_PLATFORM =~ /bsd/ ? 'gmake' : 'make')))
end

# Copy test files (this intentionally overwrites existing files!)
system("cp #{libdir}/testdata/* #{gemdir}/spec/files/")

$objs = ['pg_query_ruby.o']

$LOCAL_LIBS << '-lpg_query'
$LIBPATH << libdir
$CFLAGS << " -I #{libdir} -O3 -Wall -fno-strict-aliasing -fwrapv -g"

SYMFILE = File.join(__dir__, 'pg_query_ruby.sym')
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
else
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'

# To update the protobufs, run this after the source has been downloaded:
# protoc --proto_path=tmp/x86_64-darwin19/pg_query/2.6.3/libpg_query-13-latest-develop-protobuf/protobuf --ruby_out=lib/pg_query tmp/x86_64-darwin19/pg_query/2.6.3/libpg_query-13-latest-develop-protobuf/protobuf/*.proto