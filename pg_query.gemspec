$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'pg_query/version'

Gem::Specification.new do |s|
  s.name        = 'pg_query'
  s.version     = PgQuery::VERSION

  s.summary     = 'PostgreSQL query parsing and normalization library'
  s.description = 'Parses SQL queries using a copy of the PostgreSQL server query parser'
  s.author      = 'Lukas Fittl'
  s.email       = 'lukas@fittl.com'
  s.license     = 'BSD-3-Clause'
  s.homepage    = 'https://github.com/pganalyze/pg_query'

  s.metadata['rubygems_mfa_required'] = 'true'

  s.required_ruby_version = '>= 3.0'

  s.extensions = %w[ext/pg_query/extconf.rb]

  s.files = Dir['CHANGELOG.md', 'LICENSE', 'README.md', 'Rakefile', 'lib/**/*.rb',
                'ext/pg_query/*.{c,h,sym,rb}', 'ext/pg_query/include/**/*']

  # Don't unnecessarily include the Postgres source in rdoc (sloooow!)
  s.rdoc_options     = %w[--main README.md --exclude ext/]
  s.extra_rdoc_files = %w[CHANGELOG.md README.md]

  s.add_dependency 'google-protobuf', '>= 3.25.3'
end
