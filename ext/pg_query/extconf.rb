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

# "ruby_abi_version" is a required symbol to be exported on Ruby 3.2+ development releases
# See https://github.com/ruby/ruby/pull/5474 and https://github.com/ruby/ruby/pull/6231
def export_ruby_abi_version
  return false if RUBY_PATCHLEVEL >= 0 # Not a development release
  m = /(\d+)\.(\d+)/.match(RUBY_VERSION)
  return false if m.nil?
  major = m[1].to_i
  minor = m[2].to_i
  major >= 3 && minor >= 2
end

def ext_symbols_filename
  name = 'ext_symbols'
  name += '_freebsd' if RUBY_PLATFORM =~ /freebsd/
  name += '_openbsd' if RUBY_PLATFORM =~ /openbsd/
  name += '_with_ruby_abi_version' if export_ruby_abi_version
  "#{name}.sym"
end

SYMFILE = File.join(__dir__, ext_symbols_filename)

if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
elsif RUBY_PLATFORM !~ /cygwin|mswin|mingw|bccwin|wince|emx/
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
