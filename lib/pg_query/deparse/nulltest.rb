# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::NULLTEST
  def self.call(node, context)
    result = []

    result << PgQuery::Deparse.from(node["arg"])

    if node["nulltesttype"] == 0
      result << 'IS NULL'
    end

    if node["nulltesttype"] == 1
      result << 'IS NOT NULL'
    end

    return result.join(' ')
  end
end
