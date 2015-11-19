# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::RANGEVAR
  def self.call(node, context)
    if context == "relpersistence"
      case node["relpersistence"]
      when "t"
        return "TEMPORARY"
      when "u"
        return "UNLOGGED"
      when "p"
        return ""
      else
        fail format("Unknown persistence type %s", node["relpersistence"])
      end
    end

    result = []

    if node["inhOpt"] == 0
      result << 'ONLY'
    end

    result << node["relname"]

    if node["alias"]
      result << PgQuery::Deparse.from(node["alias"])
    end

    return result.join(' ')
  end
end
