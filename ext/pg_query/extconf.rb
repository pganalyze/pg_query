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

def have_ruby_abi_version()
  # ruby_abi_version is only available in development versions: https://github.com/ruby/ruby/pull/6231
  return false if RUBY_PATCHLEVEL >= 0

  m = /(\d+)\.(\d+)/.match(RUBY_VERSION)
  if m.nil?
    puts "Failed to parse ruby version: #{RUBY_VERSION}. Assuming ruby_abi_version symbol is NOT present."
    return false
  end
  major = m[1].to_i
  minor = m[2].to_i
  if major >= 3 and minor >= 2
    puts "Ruby version #{RUBY_VERSION} >= 3.2. Assuming ruby_abi_version symbol is present."
    return true
  end
  puts "Ruby version #{RUBY_VERSION} < 3.2. Assuming ruby_abi_version symbol is NOT present."
  false
end

def ext_export_filename()
  name = if RUBY_PLATFORM =~ /freebsd/
    'pg_query_ruby_freebsd'
  elsif RUBY_PLATFORM !~ /cygwin|mswin|mingw|bccwin|wince|emx/
    'pg_query_ruby'
  end
  name += '-with-ruby-abi-version' if have_ruby_abi_version()
  "#{name}.sym"
end

SYMFILE = File.join(__dir__, ext_export_filename())

if RUBY_PLATFORM =~ /darwin/
  $DLDFLAGS << " -Wl,-exported_symbols_list #{SYMFILE}" unless defined?(::Rubinius)
elsif RUBY_PLATFORM !~ /cygwin|mswin|mingw|bccwin|wince|emx/
  $DLDFLAGS << " -Wl,--retain-symbols-file=#{SYMFILE}"
end

create_makefile 'pg_query/pg_query'
