class PgQuery
  def param_refs
    results = []
    exprs = parsetree.dup
    loop do
      expr = exprs.shift

      if expr.is_a?(Hash)
        expr.each do |k,v|
          if v.is_a?(Hash)
            if v["PARAMREF"]
              length = 1 # FIXME: Not true when we have actual paramrefs
              results << {"location" => v["PARAMREF"]["location"], "length" => length}
              next
            elsif (p = v["TYPECAST"]["arg"]["PARAMREF"] rescue false) && (t = v["TYPECAST"]["typeName"]["TYPENAME"] rescue false)
              location = p["location"]
              typeloc = t["location"]
              typename = t["names"].join(".")
              length = 1 # FIXME: Not true when we have actual paramrefs
              if typeloc < location
                length += location - typeloc
                location = typeloc
              end
              results << {"location" => location, "length" => length, "typename" => typename}
              next
            end
          end

          exprs << v if !v.nil?
        end
      elsif expr.is_a?(Array)
        exprs += expr
      end

      break if exprs.empty?
    end
    results.sort_by! {|r| r["location"] }
    results
  end
end
