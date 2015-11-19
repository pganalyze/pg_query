# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::ALTER_TABLE_CMD
  def self.call(node, context)
    result = []

    command_and_options = PgQuery::DeparseHelper::ALTER_TABLE_COMMANDS.call(node)

    command = command_and_options[0]

    options = command_and_options[1]

    if command
      result << command
    end

    if node["missing_ok"]
      result << 'IF EXISTS'
    end

    if node["name"]
      result << node["name"]
    end

    if options
      result << options
    end

    if node["def"]
      result << PgQuery::Deparse.from(node["def"])
    end

    if node["behavior"] == 1
      result << 'CASCADE'
    end

    return result.join(' ')
  end
end
