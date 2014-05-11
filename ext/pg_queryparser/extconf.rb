require 'mkmf'

workdir = Dir.pwd
pgdir = File.join(workdir, "postgres")

# Download & compile PostgreSQL if we don't have it yet
#
# Note: We intentionally use a patched version that fixes bugs in outfuncs.c
if !Dir.exists?(pgdir)
  unless File.exists?("#{workdir}/postgres.zip")
    system("curl https://codeload.github.com/pganalyze/postgres/zip/more-outfuncs -o #{workdir}/postgres.zip") || raise("ERROR")
  end
  system("unzip -q #{workdir}/postgres.zip -d #{workdir}") || raise("ERROR")
  system("mv #{workdir}/postgres-more-outfuncs #{pgdir}") || raise("ERROR")
  system("cd #{pgdir}; ./configure") || raise("ERROR")
  system("cd #{pgdir}; make") || raise("ERROR")
end

$objs = `find #{pgdir}/src/backend -name '*.o' | egrep -v '(main/main\.o|snowball|libpqwalreceiver|conversion_procs)' | xargs echo`
$objs += " #{pgdir}/src/timezone/localtime.o #{pgdir}/src/timezone/strftime.o #{pgdir}/src/timezone/pgtz.o"
$objs += " #{pgdir}/src/common/libpgcommon_srv.a #{pgdir}/src/port/libpgport_srv.a"
$objs = $objs.split(" ")

$objs << File.join(File.dirname(__FILE__), "pg_queryparser.o")

$CFLAGS << " -I #{pgdir}/src/include"

SYMFILE = File.join(File.dirname(__FILE__), "pg_queryparser.sym")
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << "-exported_symbols_list #{SYMFILE}"
else
  $DLDFLAGS << "-export-symbols #{SYMFILE}"
end

create_makefile 'pg_queryparser/pg_queryparser'