# rubocop:disable Style/GlobalVars

require 'digest'
require 'mkmf'
require 'open-uri'

$objs = Dir.glob(File.join(__dir__, '*.c')).map { |f| f.gsub('.c', '.o') }

$CFLAGS << " -I#{File.join(__dir__, 'include')} -O3 -Wall -fno-strict-aliasing -fwrapv -fstack-protector -Wno-unused-function -Wno-unused-variable -g"

SYMFILE = File.join(__dir__, 'pg_query_ruby.sym')
if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
else
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
