# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::INSERT_INTO
  def self.call(node, context)
    result = []

    if node["withClause"]
      result << PgQuery::Deparse.from(node["withClause"])
    end

    result << 'INSERT INTO'

    result << PgQuery::Deparse.from(node["relation"])

    if node["cols"]
      parts = []
      node["cols"].each do |column|
        parts << PgQuery::Deparse.from(column)
      end
      result << format("(%s)", parts.join(', '))
    end

    result << PgQuery::Deparse.from(node["selectStmt"])

    return result.join(' ')
  end
end
