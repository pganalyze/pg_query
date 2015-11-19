# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::COMMONTABLEEXPR
  def self.call(node, context)
    result = []

    result << node["ctename"]

    if node["aliascolnames"]
      result << format("(%s)", node["aliascolnames"].join(', '))
    end

    result << format("AS (%s)", PgQuery::Deparse.from(node["ctequery"]))

    return result.join(' ')
  end
end
