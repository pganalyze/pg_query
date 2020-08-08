class PgQuery::ParseResult
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
