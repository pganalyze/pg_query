class PgQuery
  private

  def treewalker!(normalized_parsetree, &block)
    exprs = normalized_parsetree.dup

    loop do
      expr = exprs.shift

      if expr.is_a?(Hash)
        expr.each do |k, v|
          block.call(expr, k, v)

          exprs << v unless v.nil?
        end
      elsif expr.is_a?(Array)
        exprs += expr
      end

      break if exprs.empty?
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
