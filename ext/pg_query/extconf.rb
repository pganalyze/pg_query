# rubocop:disable Style/GlobalVars

require 'mkmf'
require 'open-uri'

LIB_PG_QUERY_TAG = '9.5-latest'

workdir = Dir.pwd
libdir = File.join(workdir, 'libpg_query-' + LIB_PG_QUERY_TAG)
gemdir = File.join(File.dirname(__FILE__), '../..')

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

# Build libpg_query (and parts of PostgreSQL)
system("cd #{libdir}; make DEBUG=0")

# Cleanup the Postgres install inside libpg_query to reduce the installed size
system("rm -rf #{libdir}/postgres")
system("rm -f #{libdir}/postgres.tar.bz2")

# Copy test files (this intentionally overwrites existing files!)
system("cp #{libdir}/testdata/* #{gemdir}/spec/files/")

$objs = ['pg_query_ruby.o']

$LOCAL_LIBS << '-lpg_query'
$LIBPATH << libdir
$CFLAGS << " -I #{libdir} -O3 -Wall -Wmissing-prototypes -Wpointer-arith -Wdeclaration-after-statement -Wendif-labels -Wmissing-format-attribute -Wformat-security -fno-strict-aliasing -fwrapv"

SYMFILE = File.join(File.dirname(__FILE__), 'pg_query_ruby.sym')
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
else
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
