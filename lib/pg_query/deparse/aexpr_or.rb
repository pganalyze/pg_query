# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::AEXPR_OR
  def self.call(node, context)
    lexpr = ''

    rexpr = ''

    lexpr = PgQuery::Deparse.from(node["lexpr"])

    rexpr = PgQuery::Deparse.from(node["rexpr"])

    if node["lexpr"].keys == ["AEXPR OR"]
      lexpr = format("(%s)", lexpr)
    end

    if node["lexpr"].keys == ["AEXPR AND"]
      lexpr = format("(%s)", lexpr)
    end

    if node["rexpr"].keys == ["AEXPR OR"]
      rexpr = format("(%s)", rexpr)
    end

    if node["rexpr"].keys == ["AEXPR AND"]
      rexpr = format("(%s)", rexpr)
    end

    return format("%s OR %s", lexpr, rexpr)
  end
end
