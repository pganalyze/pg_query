class PgQuery
  # Parses a query that has been normalized by pg_stat_statements
  def self.parse_normalized(original_query)
    # Transform ? into \uFFED
    query = normalized_to_parseable_query(original_query)
    
    # Parse it!
    result = parse(query)
    
    # Transform \uFFED references as if they were $0
    parsed_to_normalized_parsetree!(result.parsetree)
    
    PgQuery.new(original_query, result.parsetree, result.warnings)
  end

protected
  # The PostgreSQL parser doesn't understand pg_stat_statements replacement characters,
  # change them into a fake column reference to an unusual unicode character \uFFED
  def self.normalized_to_parseable_query(query)
    regexps = [
      'INTERVAL ?',
      /\$[0-9]+\?/,
      '?.?',
      /(?<!\\)\?/, # Replace all ?, unless they are escaped by a backslash
    ]
    regexps.each do |re|
      query = query.gsub(re) {|m| "\uFFED" * m.size }
    end
    query
  end
  
  # Modifies the passed in parsetree to have paramrefs to $0 instead of columnref to \uFFED
  def self.parsed_to_normalized_parsetree!(parsetree)
    expressions = parsetree.dup
    loop do
      break unless expression = expressions.shift
  
      if expression.is_a?(Array)
        expressions += expression.compact
      elsif expression.is_a?(Hash)
        value = expression['COLUMNREF'] && expression['COLUMNREF']['fields']
        if value && value.size == 1 && value[0].is_a?(String) && value[0].chars.to_a.uniq == ["\uFFED"]
          expression.replace('PARAMREF' => {'number' => 0,
                                            'location' => expression['COLUMNREF']['location']})
        else
          expressions += expression.values.compact
        end
      end
    end
  end
end