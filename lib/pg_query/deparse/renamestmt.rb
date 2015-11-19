# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::RENAMESTMT
  def self.call(node, context)
    result = []

    if node["renameType"] == 26
      result << 'ALTER TABLE'
      result << PgQuery::Deparse.from(node["relation"])
      result << 'RENAME TO'
      result << node["newname"]
    end

    return result.join(' ')
  end
end
