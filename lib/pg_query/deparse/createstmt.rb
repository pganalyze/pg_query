# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::CREATESTMT
  def self.call(node, context)
    result = []

    result << 'CREATE'

    relpersistence = ''

    relpersistence = PgQuery::Deparse.from(node["relation"], 'relpersistence')

    if relpersistence != ""
      result << relpersistence
    end

    result << 'TABLE'

    if node["if_not_exists"]
      result << 'IF NOT EXISTS'
    end

    result << PgQuery::Deparse.from(node["relation"])

    parts = []

    node["tableElts"].each do |item|
      parts << PgQuery::Deparse.from(item)
    end

    result << format("(%s)", parts.join(', '))

    if node["inhRelations"]
      result << 'INHERITS'
      other_parts = []
      node["inhRelations"].each do |relation|
        other_parts << PgQuery::Deparse.from(relation)
      end
      result << format("(%s)", other_parts.join(', '))
    end

    return result.join(' ')
  end
end
