# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::DEFELEM
  def self.call(node, context)
    if node["defname"] == "as"
      return format("AS $$%s$$", node["arg"].join('
      '))
    end

    if node["defname"] == "language"
      return format("language %s", node["arg"])
    end

    return format("%s", node["arg"])
  end
end
