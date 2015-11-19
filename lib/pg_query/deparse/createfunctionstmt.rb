# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::CREATEFUNCTIONSTMT
  def self.call(node, context)
    result = []

    result << 'CREATE FUNCTION'

    parameters = []

    node["parameters"].each do |item|
      parameters << PgQuery::Deparse.from(item)
    end

    arguments = ''

    arguments = parameters.join(', ')

    result << format("%s(%s)", node["funcname"][0], arguments)

    result << 'RETURNS'

    result << PgQuery::Deparse.from(node["returnType"])

    node["options"].each do |item|
      result << PgQuery::Deparse.from(item)
    end

    return result.join(' ')
  end
end
