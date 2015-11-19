# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::CONSTRAINT
  def self.call(node, context)
    result = []

    if node["conname"]
      result << 'CONSTRAINT'
      result << node["conname"]
    end

    result << node["contype"].gsub('_', ' ')

    if node["raw_expr"]
      if node["raw_expr"].keys == ["AEXPR"]
        result << format("(%s)", PgQuery::Deparse.from(node["raw_expr"]))
      end
      if node["raw_expr"].keys != ["AEXPR"]
        result << PgQuery::Deparse.from(node["raw_expr"])
      end
    end

    if node["keys"]
      result << format("(%s)", node["keys"].join(', '))
    end

    if node["indexname"]
      result << format("USING INDEX %s", node["indexname"])
    end

    return result.join(' ')
  end
end
