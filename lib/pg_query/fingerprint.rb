require 'digest'

class PgQuery
  def fingerprint # rubocop:disable Style/CyclomaticComplexity
    normalized_parsetree = deep_dup(parsetree)
    exprs = normalized_parsetree.dup
    loop do
      expr = exprs.shift

      if expr.is_a?(Hash)
        expr.each do |k, v|
          if v.is_a?(Hash) && %w(A_CONST ALIAS PARAMREF).include?(v.keys[0])
            # Remove constants, aliases and param references from tree
            expr[k] = nil
          elsif k == 'location'
            # Remove location info in order to ignore whitespace and target list ordering
            expr.delete(k)
          elsif !v.nil?
            # Remove SELECT target list names & ignore order
            if k == 'targetList' && v.is_a?(Array)
              v.each { |v2| v2['RESTARGET']['name'] = nil if v2['RESTARGET'] } # Remove names
              v.sort_by! { |v2| v2.to_s }
              expr[k] = v
            end

            # Ignore INSERT cols order
            if k == 'cols' && v.is_a?(Array)
              v.sort_by! { |v2| v2.to_s }
              expr[k] = v
            end

            # Process sub-expressions
            exprs << v
          end
        end
      elsif expr.is_a?(Array)
        exprs += expr
      end

      break if exprs.empty?
    end

    Digest::SHA1.hexdigest(normalized_parsetree.to_s)
  end

  private

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
