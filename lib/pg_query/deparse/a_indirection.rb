# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::A_INDIRECTION
  def self.call(node, context)
    result = []

    result << PgQuery::Deparse.from(node["arg"])

    node["indirection"].each do |subnode|
      result << PgQuery::Deparse.from(subnode)
    end

    return result.join('')
  end
end
