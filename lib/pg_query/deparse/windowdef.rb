# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::WINDOWDEF
  def self.call(node, context)
    result = []

    if node["partitionClause"]
      result << 'PARTITION BY'
      parts = []
      node["partitionClause"].each do |item|
        parts << PgQuery::Deparse.from(item)
      end
      result << parts.join(', ')
    end

    if node["orderClause"]
      result << 'ORDER BY'
      parts = []
      node["orderClause"].each do |item|
        parts << PgQuery::Deparse.from(item)
      end
      result << parts.join(', ')
    end

    return result.join(' ')
  end
end
