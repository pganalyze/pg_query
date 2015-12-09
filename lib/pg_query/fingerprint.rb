require 'digest'

class PgQuery
  A_EXPR_IN = 9

  def fingerprint(hash: Digest::SHA1.new) # rubocop:disable Metrics/CyclomaticComplexity
    exprs = parsetree.dup

    loop do
      expr = exprs.shift

      if expr.is_a?(Hash)
        expr.sort_by { |k, _| k }.reverse_each do |k, v|
          next if [A_CONST, ALIAS, PARAM_REF, 'location'].include?(k)

          if k == 'targetList' && !v.nil?
            values = deep_dup(v)
            values.each do |v2|
              v2[RES_TARGET].delete('location')
              v2[RES_TARGET].delete('name')
            end
            values.sort_by!(&:to_s)
            exprs.unshift(values)
          elsif k == 'cols' && !v.nil?
            values = deep_dup(v)
            values.each do |v2|
              v2[RES_TARGET].delete('location')
            end
            values.sort_by!(&:to_s)
            exprs.unshift(values)
          elsif k == A_EXPR && v['kind'] == A_EXPR_IN && !v['rexpr'].nil?
            # Compact identical IN list elements to one
            hsh = deep_dup(v)
            treewalker! hsh['rexpr'] do |expr2, k2, _v|
              next unless k2 == 'location'
              expr2.delete(k2)
            end
            hsh['rexpr'].uniq!
            exprs.unshift(hsh)
          elsif v.is_a?(Hash)
            exprs.unshift(v)
          elsif v.is_a?(Array)
            exprs = v + exprs
          elsif !v.nil?
            exprs.unshift(v)
          end

          exprs.unshift(k) if k[/^[A-Z]+/]
        end
      elsif expr.is_a?(Array)
        exprs = expr + exprs
      else
        hash.update expr.to_s
      end

      break if exprs.empty?
    end

    hash.hexdigest
  end
end
