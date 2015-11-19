# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::SUBLINK
  def self.call(node, context)
    subselect = ''

    subselect = PgQuery::Deparse.from(node["subselect"])

    if node["subLinkType"] == 2
      if node["operName"][0] == "="
        testexpr = ''
        testexpr = PgQuery::Deparse.from(node["testexpr"])
        return format("%s IN (%s)", testexpr, subselect)
      end
    end

    if node["subLinkType"] == 0
      return format("EXISTS(%s)", subselect)
    end

    return format("(%s)", subselect)
  end
end
