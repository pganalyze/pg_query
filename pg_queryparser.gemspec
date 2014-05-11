$:.push File.expand_path("../lib", __FILE__)
require 'pg_queryparser/version'

Gem::Specification.new do |s|
  s.name        = 'pg_queryparser'
  s.version     = PgQueryparser::VERSION
  
  s.summary     = 'PostgreSQL query parsing and normalization library'
  s.description = 'Uses the actual PostgreSQL server source to parse SQL queries and return the internal PostgreSQL parsetree'
  s.author      = 'Lukas Fittl'
  s.email       = 'lukas@fittl.com'
  s.license     = 'MIT'
  s.homepage    = 'http://github.com/pganalyze/pg_queryparser'
  
  s.extensions = %w[ext/pg_queryparser/extconf.rb]

  s.files = %w[
    LICENSE
    Rakefile
    ext/pg_queryparser/extconf.rb
    ext/pg_queryparser/pg_queryparser.c
    ext/pg_queryparser/pg_queryparser.sym
    lib/pg_queryparser.rb
    lib/pg_queryparser/parse.rb
    lib/pg_queryparser/parse_error.rb
    lib/pg_queryparser/version.rb
  ]
  
  s.add_development_dependency "rake-compiler", '~> 0'
  s.add_development_dependency 'rspec', '~> 2.0'
  
  s.add_runtime_dependency "json", '~> 1.8'
end