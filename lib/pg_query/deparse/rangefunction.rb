# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::RANGEFUNCTION
  def self.call(node, context)
    result = []

    if node["lateral"]
      result << 'LATERAL'
    end

    result << PgQuery::Deparse.from(node["functions"][0][0])

    if node["alias"]
      result << PgQuery::Deparse.from(node["alias"])
    end

    return result.join(' ')
  end
end
