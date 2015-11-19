# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::AEXPR_NOT
  def self.call(node, context)
    return format("NOT %s", PgQuery::Deparse.from(node["rexpr"]))
  end
end
