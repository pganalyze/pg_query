# rubocop:disable Style/GlobalVars

require 'mkmf'
require 'open-uri'

LIB_PG_QUERY_TAG = '9.5-1.4.0'

workdir = Dir.pwd
libdir = File.join(workdir, 'libpg_query-' + LIB_PG_QUERY_TAG)
gemdir = File.join(File.dirname(__FILE__), '../..')
libfile = libdir + '/libpg_query.a'

unless File.exist?("#{workdir}/libpg_query.tar.gz")
  File.open("#{workdir}/libpg_query.tar.gz", 'wb') do |target_file|
    open('https://codeload.github.com/lfittl/libpg_query/tar.gz/' + LIB_PG_QUERY_TAG, 'rb') do |read_file|
      target_file.write(read_file.read)
    end
  end
end

unless Dir.exist?(libdir)
  system("tar -xf #{workdir}/libpg_query.tar.gz") || fail('ERROR')
end

unless Dir.exist?(libfile)
  # Build libpg_query (and parts of PostgreSQL)
  system("cd #{libdir}; make build")
end

# Copy test files (this intentionally overwrites existing files!)
system("cp #{libdir}/testdata/* #{gemdir}/spec/files/")

$objs = ['pg_query_ruby.o']

$LOCAL_LIBS << '-lpg_query'
$LIBPATH << libdir
$CFLAGS << " -I #{libdir} -O3 -Wall -fno-strict-aliasing -fwrapv"

SYMFILE = File.join(File.dirname(__FILE__), 'pg_query_ruby.sym')
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
else
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
