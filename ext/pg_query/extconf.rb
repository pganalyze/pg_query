# rubocop:disable Style/GlobalVars

require 'digest'
require 'mkmf'
require 'open-uri'
require 'pathname'

$objs = Dir.glob(File.join(__dir__, '*.c')).map { |f| Pathname.new(f).sub_ext('.o').to_s }

if RUBY_PLATFORM !~ /cygwin|mswin|mingw|bccwin|wince|emx/
  $CFLAGS << " -fvisibility=hidden -O3 -Wall -fno-strict-aliasing -fwrapv -fstack-protector -Wno-unused-function -Wno-unused-variable -Wno-clobbered -Wno-sign-compare -Wno-discarded-qualifiers -Wno-unknown-warning-option -g"
end

$INCFLAGS = "-I#{File.join(__dir__, 'include')} " + "-I#{File.join(__dir__, 'include', 'postgres')} " + $INCFLAGS

if RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/
  $INCFLAGS = "-I#{File.join(__dir__, 'include', 'postgres', 'port', 'win32')} " + $INCFLAGS
end

if RUBY_PLATFORM =~ /mswin/
  $INCFLAGS = "-I#{File.join(__dir__, 'include', 'postgres', 'port', 'win32_msvc')} " + $INCFLAGS
end

SYMFILE =
  if RUBY_PLATFORM =~ /freebsd/
    File.join(__dir__, 'pg_query_ruby_freebsd.sym')
  elsif RUBY_PLATFORM !~ /cygwin|mswin|mingw|bccwin|wince|emx/
    File.join(__dir__, 'pg_query_ruby.sym')
  end

if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
elsif RUBY_PLATFORM !~ /cygwin|mswin|mingw|bccwin|wince|emx/
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
