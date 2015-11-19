# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::VIEWSTMT
  def self.call(node, context)
    result = []

    result << 'CREATE'

    if node["replace"]
      result << 'OR REPLACE'
    end

    relpersistence = ''

    relpersistence = PgQuery::Deparse.from(node["view"], 'relpersistence')

    if relpersistence != ""
      result << relpersistence
    end

    result << 'VIEW'

    result << PgQuery::Deparse.from(node["view"])

    if node["aliases"]
      result << format("(%s)", node["aliases"].join(', '))
    end

    result << 'AS'

    result << PgQuery::Deparse.from(node["query"])

    if node["withCheckOption"] == 1
      result << 'WITH CHECK OPTION'
    end

    if node["withCheckOption"] == 2
      result << 'WITH CASCADED CHECK OPTION'
    end

    return result.join(' ')
  end
end
