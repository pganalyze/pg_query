# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::A_ARRAYEXPR
  def self.call(node, context)
    result = []

    node["elements"].each do |element|
      result << PgQuery::Deparse.from(element)
    end

    return format("ARRAY[%s]", result.join(', '))
  end
end
