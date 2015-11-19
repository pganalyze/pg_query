# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::SORTBY
  def self.call(node, context)
    result = []

    result << PgQuery::Deparse.from(node["node"])

    if node["sortby_dir"] == 1
      result << 'ASC'
    end

    if node["sortby_dir"] == 2
      result << 'DESC'
    end

    return result.join(' ')
  end
end
