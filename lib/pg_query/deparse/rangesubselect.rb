# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::RANGESUBSELECT
  def self.call(node, context)
    result = []

    result << format("(%s)", PgQuery::Deparse.from(node["subquery"]))

    if node["alias"]
      result << PgQuery::Deparse.from(node["alias"])
    end

    return result.join(' ')
  end
end
