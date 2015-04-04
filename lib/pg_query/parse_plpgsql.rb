class PgQuery
  def self.parse_plpgsql(func_def)
    parsetree, stderr = _raw_parse_plpgsql(func_def)

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

    PgQuery.new(func_def, parsetree, warnings)
  end
end
