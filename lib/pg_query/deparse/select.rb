# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::SELECT
  def self.call(node, context)
    result = []

    if node["op"] == 1
      result << PgQuery::Deparse.from(node["larg"])
      result << 'UNION'
      if node["all"]
        result << 'ALL'
      end
      result << PgQuery::Deparse.from(node["rarg"])
      return result.join(' ')
    end

    if node["withClause"]
      result << PgQuery::Deparse.from(node["withClause"])
    end

    if node["targetList"]
      result << 'SELECT'
      target_list = []
      node["targetList"].each do |item|
        target_list << PgQuery::Deparse.from(item, 'select')
      end
      result << target_list.join(', ')
    end

    if node["fromClause"]
      result << 'FROM'
      from_list = []
      node["fromClause"].each do |item|
        from_list << PgQuery::Deparse.from(item)
      end
      result << from_list.join(', ')
    end

    if node["whereClause"]
      result << 'WHERE'
      result << PgQuery::Deparse.from(node["whereClause"])
    end

    if node["valuesLists"]
      result << 'VALUES'
      value_lists = []
      node["valuesLists"].each do |value_list|
        parts = []
        value_list.each do |item|
          parts << PgQuery::Deparse.from(item)
        end
        value_lists << format("(%s)", parts.join(', '))
      end
      result << value_lists.join(', ')
    end

    if node["groupClause"]
      result << 'GROUP BY'
      parts = []
      node["groupClause"].each do |item|
        parts << PgQuery::Deparse.from(item)
      end
      result << parts.join(', ')
    end

    if node["havingClause"]
      result << 'HAVING'
      result << PgQuery::Deparse.from(node["havingClause"])
    end

    if node["sortClause"]
      result << 'ORDER BY'
      parts = []
      node["sortClause"].each do |item|
        parts << PgQuery::Deparse.from(item)
      end
      result << parts.join(', ')
    end

    if node["limitCount"]
      result << 'LIMIT'
      result << PgQuery::Deparse.from(node["limitCount"])
    end

    if node["limitOffset"]
      result << 'OFFSET'
      result << PgQuery::Deparse.from(node["limitOffset"])
    end

    if node["lockingClause"]
      node["lockingClause"].each do |item|
        result << PgQuery::Deparse.from(item)
      end
    end

    return result.join(' ')
  end
end
