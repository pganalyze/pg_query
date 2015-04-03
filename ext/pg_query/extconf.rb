require 'mkmf'
require 'open-uri'

workdir = Dir.pwd
pgdir = File.join(workdir, "postgres")

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
    'nodeFuncs.o', 'makefuncs.o', 'value.o', 'list.o', 'outfuncs_json.o'
  ],
  'backend/lib' => ['stringinfo.o'],
  'port'        => ['qsort.o'],
  'common'      => ['psprintf.o'],
  'timezone'    => ['pgtz.o'],
}

# Download & compile PostgreSQL if we don't have it yet
#
# Note: We intentionally use a patched version that fixes bugs in outfuncs.c
if !Dir.exists?(pgdir)
  unless File.exists?("#{workdir}/postgres.tar.gz")
    File.open("#{workdir}/postgres.tar.gz", "wb") do |target_file|
      open("https://codeload.github.com/pganalyze/postgres/tar.gz/pg_query", "rb") do |read_file|
        target_file.write(read_file.read)
      end
    end
  end
  system("tar -xf #{workdir}/postgres.tar.gz") || raise("ERROR")
  system("mv #{workdir}/postgres-pg_query #{pgdir}") || raise("ERROR")
  system("cd #{pgdir}; CFLAGS=-fPIC ./configure -q") || raise("ERROR")
  system("cd #{pgdir}; make -C src/backend lib-recursive") # Ensures headers are generated
  PG_OBJS.each do |directory, objs|
    system("cd #{pgdir}; make -C src/#{directory} #{objs.join(' ')}")  || raise("ERROR")
  end
end

$objs = PG_OBJS.map { |directory, objs| objs.map { |obj| "#{pgdir}/src/#{directory}/#{obj}" } }.flatten
$objs += ["pg_query.o", "pg_query_parse.o", "pg_query_normalize.o", "pg_polyfills.o"]

$CFLAGS << " -I #{pgdir}/src/include"

# Similar to those used by PostgreSQL
$CFLAGS << " -O2 -Wall -Wmissing-prototypes -Wpointer-arith -Wdeclaration-after-statement -Wendif-labels -Wmissing-format-attribute -Wformat-security -fno-strict-aliasing -fwrapv"

SYMFILE = File.join(File.dirname(__FILE__), "pg_query.sym")
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
else
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
