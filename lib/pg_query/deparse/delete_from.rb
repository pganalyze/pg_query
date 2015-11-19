# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::DELETE_FROM
  def self.call(node, context)
    result = []

    if node["withClause"]
      result << PgQuery::Deparse.from(node["withClause"])
    end

    result << 'DELETE FROM'

    result << PgQuery::Deparse.from(node["relation"])

    if node["usingClause"]
      result << 'USING'
      parts = []
      node["usingClause"].each do |item|
        parts << PgQuery::Deparse.from(item)
      end
      result << parts.join(', ')
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
