# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::AEXPR
  def self.call(node, context)
    result = []

    result << PgQuery::Deparse.from(node["lexpr"], 'aexpr')

    result << node["name"][0]

    result << PgQuery::Deparse.from(node["rexpr"], 'aexpr')

    if context == "aexpr"
      return format("(%s)", result.join(' '))
    end

    return result.join(' ')
  end
end
