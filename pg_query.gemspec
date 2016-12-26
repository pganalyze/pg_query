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
  s.homepage    = 'http://github.com/lfittl/pg_query'

  s.extensions = %w(ext/pg_query/extconf.rb)

  s.files = Dir['CHANGELOG.md', 'LICENSE', 'README.md', 'Rakefile', 'lib/**/*.rb',
                'ext/pg_query/*.{c,h,sym,rb}', 'ext/pg_query/patches/*']

  # Don't unnecessarily include the Postgres source in rdoc (sloooow!)
  s.rdoc_options     = %w(--main README.md --exclude ext/)
  s.extra_rdoc_files = %w(CHANGELOG.md README.md)

  s.add_development_dependency 'rake-compiler', '~> 0'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-rspec'

  s.add_runtime_dependency 'json', '>= 1.8', '< 3'
end
