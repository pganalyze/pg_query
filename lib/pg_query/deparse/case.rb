# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::CASE
  def self.call(node, context)
    result = []

    result << 'CASE'

    node["args"].each do |arg|
      result << PgQuery::Deparse.from(arg)
    end

    if node["defresult"]
      result << 'ELSE'
      result << PgQuery::Deparse.from(node["defresult"])
    end

    result << 'END'

    return result.join(' ')
  end
end
