class PgQuery::ParseResult
  private

  def treewalker!(normalized_parsetree)
    exprs = normalized_parsetree.dup.map { |e| [e, []] }

    loop do
      expr, parent_location = exprs.shift

      if expr.is_a?(Hash)
        expr.each do |k, v|
          location = parent_location + [k]

          yield(expr, k, v, location)

          exprs << [v, location] unless v.nil?
        end
      elsif expr.is_a?(Array)
        exprs += expr.map.with_index { |e, idx| [e, parent_location + [idx]] }
      end

      break if exprs.empty?
    end
  end

  def find_tree_location(normalized_parsetree, searched_location)
    treewalker! normalized_parsetree do |expr, k, v, location|
      next unless location == searched_location
      yield(expr, k, v)
    end
  end

  def transform_nodes!(parsetree)
    result = deep_dup(parsetree)
    exprs = result.dup

    loop do
      expr = exprs.shift

      if expr.is_a?(Hash)
        yield(expr) if expr.size == 1 && expr.keys[0][/^[A-Z]+/]

        exprs += expr.values.compact
      elsif expr.is_a?(Array)
        exprs += expr
      end

      break if exprs.empty?
    end

    result
  end
end
