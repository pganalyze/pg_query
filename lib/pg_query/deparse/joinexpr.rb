# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::JOINEXPR
  def self.call(node, context)
    result = []

    result << PgQuery::Deparse.from(node["larg"])

    if node["jointype"] == 1
      result << 'LEFT'
    end

    if node["jointype"] == 0
      if !node["quals"]
        result << 'CROSS'
      end
    end

    result << 'JOIN'

    result << PgQuery::Deparse.from(node["rarg"])

    if node["quals"]
      result << 'ON'
      result << PgQuery::Deparse.from(node["quals"])
    end

    return result.join(' ')
  end
end
