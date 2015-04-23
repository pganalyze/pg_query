$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'pg_query/version'

Gem::Specification.new do |s|
  s.name        = 'pg_query'
  s.version     = PgQuery::VERSION

  s.summary     = 'PostgreSQL query parsing and normalization library'
  s.description = 'Parses SQL queries using a copy of the PostgreSQL server query parser'
  s.author      = 'Lukas Fittl'
  s.email       = 'lukas@fittl.com'
  s.license     = 'BSD-3-Clause'
  s.homepage    = 'http://github.com/pganalyze/pg_query'

  s.extensions = %w(ext/pg_query/extconf.rb)

  s.files = %w(
    LICENSE
    Rakefile
    ext/pg_query/extconf.rb
    ext/pg_query/pg_polyfills.c
    ext/pg_query/pg_query_normalize.c
    ext/pg_query/pg_query_parse.c
    ext/pg_query/pg_query.c
    ext/pg_query/pg_query.h
    ext/pg_query/pg_query.sym
    lib/pg_query.rb
    lib/pg_query/filter_columns.rb
    lib/pg_query/fingerprint.rb
    lib/pg_query/param_refs.rb
    lib/pg_query/parse_error.rb
    lib/pg_query/parse.rb
    lib/pg_query/version.rb
  )

  s.add_development_dependency 'rake-compiler', '~> 0'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-rspec'

  s.add_runtime_dependency 'json', '~> 1.8'
end
