# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::PARAMREF
  def self.call(node, context)
    if node["number"] == 0
      return "?"
    end

    return format("$%d", node["number"])
  end
end
