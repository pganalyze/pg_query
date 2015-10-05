# rubocop:disable Style/GlobalVars

require 'mkmf'
require 'open-uri'

workdir = Dir.pwd
pgdir = File.join(workdir, 'postgres')

PG_VERSION = '9.4.4'

# Limit the objects we build to speed up compilation times
PG_OBJS = {
  'backend/utils' => [
    'mb/wchar.o', 'mb/encnames.o', 'mb/mbutils.o',
    'mmgr/mcxt.o', 'mmgr/aset.o',
    'error/elog.o', 'init/globals.o',
    'adt/name.o' # namein
  ],
  'backend/parser' => [
    'gram.o', 'parser.o', 'keywords.o', 'kwlookup.o', 'scansup.o'
  ],
  'backend/nodes' => [
    'copyfuncs.o', 'nodeFuncs.o', 'makefuncs.o', 'value.o', 'list.o', 'outfuncs_json.o'
  ],
  'backend/lib' => ['stringinfo.o'],
  'port'        => ['qsort.o'],
  'common'      => ['psprintf.o'],
  'timezone'    => ['pgtz.o']
}

# Download & compile PostgreSQL if we don't have it yet
#
# Note: We intentionally use a patched version that fixes bugs in outfuncs.c
unless Dir.exist?(pgdir)
  unless File.exist?("#{workdir}/postgres.tar.gz")
    File.open("#{workdir}/postgres.tar.gz", 'wb') do |target_file|
      open(format('https://ftp.postgresql.org/pub/source/v%s/postgresql-%s.tar.bz2', PG_VERSION, PG_VERSION), 'rb') do |read_file|
        target_file.write(read_file.read)
      end
    end
  end
  system("tar -xf #{workdir}/postgres.tar.gz") || fail('ERROR')
  system("mv #{workdir}/postgresql-#{PG_VERSION} #{pgdir}") || fail('ERROR')

  # Apply patches
  Dir[File.join(File.absolute_path(File.dirname(__FILE__)), 'patches/*')].each do |patch|
    system("cd #{pgdir}; patch -p1 < #{patch}")
  end

  system("cd #{pgdir}; CFLAGS=-fPIC ./configure -q --without-readline --without-zlib") || fail('ERROR')
  system("cd #{pgdir}; make -C src/backend lib-recursive") # Ensures headers are generated
  PG_OBJS.each do |directory, objs|
    system("cd #{pgdir}; make -C src/#{directory} #{objs.join(' ')}") || fail('ERROR')
  end
end

$objs = PG_OBJS.map { |directory, objs| objs.map { |obj| "#{pgdir}/src/#{directory}/#{obj}" } }.flatten
$objs += %w(pg_query.o pg_query_parse.o pg_query_normalize.o pg_polyfills.o)

$CFLAGS << " -I #{pgdir}/src/include"

# Similar to those used by PostgreSQL
$CFLAGS << ' -O2 -Wall -Wmissing-prototypes -Wpointer-arith -Wdeclaration-after-statement -Wendif-labels -Wmissing-format-attribute -Wformat-security -fno-strict-aliasing -fwrapv'

SYMFILE = File.join(File.dirname(__FILE__), 'pg_query.sym')
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
else
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
