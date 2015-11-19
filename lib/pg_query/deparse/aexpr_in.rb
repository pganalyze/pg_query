# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::AEXPR_IN
  def self.call(node, context)
    result = []

    result << PgQuery::Deparse.from(node["lexpr"])

    if node["name"][0] == "="
      result << 'IN'
    end

    if node["name"][0] != "="
      result << 'NOT IN'
    end

    parts = []

    node["rexpr"].each do |item|
      parts << PgQuery::Deparse.from(item)
    end

    result << format("(%s)", parts.join(', '))

    return result.join(' ')
  end
end
