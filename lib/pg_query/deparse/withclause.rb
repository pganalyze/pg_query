# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::WITHCLAUSE
  def self.call(node, context)
    result = []

    result << 'WITH'

    if node["recursive"]
      result << 'RECURSIVE'
    end

    parts = []

    node["ctes"].each do |cte|
      parts << PgQuery::Deparse.from(cte)
    end

    result << parts.join(', ')

    return result.join(' ')
  end
end
