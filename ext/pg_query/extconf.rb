require 'mkmf'
require 'open-uri'

workdir = Dir.pwd
pgdir = File.join(workdir, "postgres")

# Limit the objects we build to speed up compilation times
UTILS_OBJS = [
  'mb/wchar.o', 'mb/encnames.o', 'mb/mbutils.o',
  'mmgr/mcxt.o', 'mmgr/aset.o',
  'error/elog.o', 'init/globals.o',
  'adt/name.o' # namein
]
PARSER_OBJS = [
  'gram.o', 'parser.o', 'keywords.o', 'kwlookup.o', 'scansup.o'
]
NODES_OBJS = [
  'nodeFuncs.o', 'makefuncs.o', 'value.o', 'list.o', 'outfuncs_json.o'
]

# Download & compile PostgreSQL if we don't have it yet
#
# Note: We intentionally use a patched version that fixes bugs in outfuncs.c
if !Dir.exists?(pgdir)
  unless File.exists?("#{workdir}/postgres.zip")
    File.open("#{workdir}/postgres.zip", "wb") do |target_file|
      open("https://codeload.github.com/pganalyze/postgres/zip/pg_query", "rb") do |read_file|
        target_file.write(read_file.read)
      end
    end
  end
  system("unzip -q #{workdir}/postgres.zip -d #{workdir}") || raise("ERROR")
  system("mv #{workdir}/postgres-pg_query #{pgdir}") || raise("ERROR")
  system("cd #{pgdir}; CFLAGS=-fPIC ./configure -q") || raise("ERROR")
  system("cd #{pgdir}; make -C src/backend lib-recursive") # This also ensures headers are generated
  system("cd #{pgdir}; make -C src/backend/utils  #{UTILS_OBJS.join(' ')}")  || raise("ERROR")
  system("cd #{pgdir}; make -C src/backend/parser #{PARSER_OBJS.join(' ')}") || raise("ERROR")
  system("cd #{pgdir}; make -C src/backend/nodes  #{NODES_OBJS.join(' ')}")  || raise("ERROR")
  system("cd #{pgdir}; make -C src/port") || raise("ERROR")
  system("cd #{pgdir}; make -C src/common libpgcommon_srv.a") || raise("ERROR")
end

$objs = []
$objs << 'timezone/pgtz.o'
$objs << 'common/libpgcommon_srv.a'
$objs << 'port/libpgport_srv.a'
$objs << 'backend/lib/stringinfo.o'
$objs += UTILS_OBJS.map  { |o| 'backend/utils/' + o }
$objs += PARSER_OBJS.map { |o| 'backend/parser/' + o }
$objs += NODES_OBJS.map  { |o| 'backend/nodes/' + o }

$objs.map! { |obj| "#{pgdir}/src/#{obj}" }

$objs << File.join(File.dirname(__FILE__), "pg_query.o")
$objs << File.join(File.dirname(__FILE__), "pg_polyfills.o")

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
