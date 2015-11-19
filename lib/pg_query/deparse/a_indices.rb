# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::A_INDICES
  def self.call(node, context)
    return format("[%s]", PgQuery::Deparse.from(node["uidx"]))
  end
end
