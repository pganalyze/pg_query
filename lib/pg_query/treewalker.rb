class PgQuery
  private

  def treewalker!(normalized_parsetree, &block)
    exprs = normalized_parsetree.dup.map { |e| [e, []] }

    loop do
      expr, parent_location = exprs.shift

      if expr.is_a?(Hash)
        expr.each do |k, v|
          location = parent_location + [k]

          block.call(expr, k, v, location)

          exprs << [v, location] unless v.nil?
        end
      elsif expr.is_a?(Array)
        exprs += expr.map.with_index { |e, idx| [e, parent_location + [idx]] }
      end

      break if exprs.empty?
    end
  end

  def find_tree_location(normalized_parsetree, searched_location, &block)
    treewalker! normalized_parsetree do |expr, k, v, location|
      next unless location == searched_location
      block.call(expr, k, v)
    end
  end

  def deep_dup(obj)
    case obj
    when Hash
      obj.each_with_object(obj.dup) do |(key, value), hash|
        hash[deep_dup(key)] = deep_dup(value)
      end
    when Array
      obj.map { |it| deep_dup(it) }
    when NilClass, FalseClass, TrueClass, Symbol, Numeric
      obj # Can't be duplicated
    else
      obj.dup
    end
  end
end
