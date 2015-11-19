# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::WHEN
  def self.call(node, context)
    result = []

    result << 'WHEN'

    result << PgQuery::Deparse.from(node["expr"])

    result << 'THEN'

    result << PgQuery::Deparse.from(node["result"])

    return result.join(' ')
  end
end
