# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::LOCKINGCLAUSE
  def self.call(node, context)
    result = []

    case node["strength"]
    when 0
      result << 'FOR KEY SHARE'
    when 1
      result << 'FOR SHARE'
    when 2
      result << 'FOR NO KEY UPDATE'
    when 3
      result << 'FOR UPDATE'
    end

    if node["lockedRels"]
      result << 'OF'
      parts = []
      node["lockedRels"].each do |item|
        parts << PgQuery::Deparse.from(item)
      end
      result << parts.join(', ')
    end

    return result.join(' ')
  end
end
