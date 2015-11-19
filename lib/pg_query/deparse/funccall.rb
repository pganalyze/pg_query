# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::FUNCCALL
  def self.call(node, context)
    result = []

    args = []

    if node["args"]
      node["args"].each do |arg|
        args << PgQuery::Deparse.from(arg)
      end
    end

    if node["agg_star"]
      args << '*'
    end

    args_str = ''

    args_str = args.join(', ')

    name = []

    node["funcname"].each do |item|
      if item != "pg_catalog"
        name << item
      end
    end

    name_str = ''

    name_str = name.join('.')

    result << format("%s(%s)", name_str, args_str)

    if node["over"]
      result << format("OVER (%s)", PgQuery::Deparse.from(node["over"]))
    end

    return result.join(' ')
  end
end
