# rubocop:disable Style/GlobalVars

require 'digest'
require 'mkmf'
require 'open-uri'
require 'pathname'

$objs = Dir.glob(File.join(__dir__, '*.c')).map { |f| Pathname.new(f).sub_ext('.o').to_s }

$CFLAGS << " -fvisibility=hidden -O3 -Wall -fno-strict-aliasing -fwrapv -fstack-protector -Wno-unused-function -Wno-unused-variable -Wno-clobbered -Wno-sign-compare -Wno-discarded-qualifiers -g"

$INCFLAGS = "-I#{File.join(__dir__, 'include')} " + $INCFLAGS

SYMFILE = File.join(__dir__, 'pg_query_ruby.sym')
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
else
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
