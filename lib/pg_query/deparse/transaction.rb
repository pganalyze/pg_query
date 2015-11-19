# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::TRANSACTION
  def self.call(node, context)
    result = []

    case node["kind"]
    when 0
      result << 'BEGIN'
    when 2
      result << 'COMMIT'
    when 3
      result << 'ROLLBACK'
    when 4
      result << 'SAVEPOINT'
    when 5
      result << 'RELEASE'
    when 6
      result << 'ROLLBACK TO SAVEPOINT'
    else
      fail ArgumentError
    end

    if node["options"]
      node["options"].each do |item|
        result << PgQuery::Deparse.from(item)
      end
    end

    return result.join(' ')
  end
end
