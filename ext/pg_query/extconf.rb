# rubocop:disable Style/GlobalVars

require 'mkmf'
require 'open-uri'

workdir = Dir.pwd
libdir = File.join(workdir, 'libpg_query-master')

unless File.exist?("#{workdir}/libpg_query.tar.gz")
  File.open("#{workdir}/libpg_query.tar.gz", 'wb') do |target_file|
    open('https://codeload.github.com/lfittl/libpg_query/tar.gz/master', 'rb') do |read_file|
      target_file.write(read_file.read)
    end
  end
end

unless Dir.exist?(libdir)
  system("tar -xf #{workdir}/libpg_query.tar.gz") || fail('ERROR')
end

# Build libpg_query (and parts of PostgreSQL)
system("cd #{libdir}; make")

$objs = ['pg_query_ruby.o']

$LOCAL_LIBS << '-lpg_query'
$LIBPATH << libdir
$CFLAGS << " -I #{libdir} -O2 -Wall -Wmissing-prototypes -Wpointer-arith -Wdeclaration-after-statement -Wendif-labels -Wmissing-format-attribute -Wformat-security -fno-strict-aliasing -fwrapv"

SYMFILE = File.join(File.dirname(__FILE__), 'pg_query_ruby.sym')
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
else
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
