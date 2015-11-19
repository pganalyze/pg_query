# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::ALIAS
  def self.call(node, context)
    result = []

    result << node["aliasname"]

    if node["colnames"]
      result << format("(%s)", node["colnames"].join(', '))
    end

    return result.join('')
  end
end
