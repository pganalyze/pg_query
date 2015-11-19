# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::COLUMNDEF
  def self.call(node, context)
    result = []

    if node["colname"]
      result << node["colname"]
    end

    if node["typeName"]
      result << PgQuery::Deparse.from(node["typeName"])
    end

    if node["raw_default"]
      result << 'USING'
      result << PgQuery::Deparse.from(node["raw_default"])
    end

    if node["constraints"]
      node["constraints"].each do |item|
        result << PgQuery::Deparse.from(item)
      end
    end

    return result.join(' ')
  end
end
