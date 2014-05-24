require 'json'

class PgQuery
  def self.parse(query)
    parsetree, stderr = _raw_parse(query)

    begin
      parsetree = JSON.parse(parsetree, max_nesting: 1000)
    rescue JSON::ParserError => e
      raise ParseError.new("Failed to parse JSON", -1)
    end

    warnings = []
    stderr.each_line do |line|
      next unless line[/^WARNING/]
      warnings << line.strip
    end

    PgQuery.new(query, parsetree, warnings)
  end

  attr_reader :query
  attr_reader :parsetree
  attr_reader :warnings
  def initialize(query, parsetree, warnings = [])
    @query = query
    @parsetree = parsetree
    @warnings = warnings
  end
end