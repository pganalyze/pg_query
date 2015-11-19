# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::AEXPR_ANY
  def self.call(node, context)
    result = []

    result << PgQuery::Deparse.from(node["lexpr"])

    result << node["name"][0]

    result << format("ANY(%s)", PgQuery::Deparse.from(node["rexpr"]))

    return result.join(' ')
  end
end
