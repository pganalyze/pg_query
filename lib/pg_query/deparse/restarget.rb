# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::RESTARGET
  def self.call(node, context)
    if !node["val"]
      return format("%s", node["name"])
    end

    val = ''

    val = PgQuery::Deparse.from(node["val"])

    if !node["name"]
      return format("%s", val)
    end

    if context == "select"
      return format("%s AS %s", val, node["name"])
    end

    if context == "update"
      return format("%s = %s", node["name"], val)
    end

    fail ArgumentError
  end
end
