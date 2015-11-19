# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::COLUMNREF
  def self.call(node, context)
    result = []

    node["fields"].each do |field|
      result << PgQuery::Deparse.from(field)
    end

    return result.join('.')
  end
end
