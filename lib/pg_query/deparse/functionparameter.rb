# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::FUNCTIONPARAMETER
  def self.call(node, context)
    return PgQuery::Deparse.from(node["argType"])
  end
end
