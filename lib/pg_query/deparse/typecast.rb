# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::TYPECAST
  def self.call(node, context)
    typename = ''

    arg = ''

    typename = PgQuery::Deparse.from(node["typeName"])

    arg = PgQuery::Deparse.from(node["arg"])

    if typename == "boolean"
      if arg == "'t'"
        return "true"
      end
      return "false"
    end

    return format("%s::%s", arg, typename)
  end
end
