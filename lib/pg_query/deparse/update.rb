# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::UPDATE
  def self.call(node, context)
    result = []

    if node["withClause"]
      result << PgQuery::Deparse.from(node["withClause"])
    end

    result << 'UPDATE'

    result << PgQuery::Deparse.from(node["relation"])

    if node["targetList"]
      result << 'SET'
      node["targetList"].each do |item|
        result << PgQuery::Deparse.from(item, 'update')
      end
    end

    if node["whereClause"]
      result << 'WHERE'
      result << PgQuery::Deparse.from(node["whereClause"])
    end

    if node["returningList"]
      result << 'RETURNING'
      parts = []
      node["returningList"].each do |item|
        parts << PgQuery::Deparse.from(item, 'select')
      end
      result << parts.join(', ')
    end

    return result.join(' ')
  end
end
