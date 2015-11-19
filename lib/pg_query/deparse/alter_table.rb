# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::ALTER_TABLE
  def self.call(node, context)
    result = []

    result << 'ALTER TABLE'

    result << PgQuery::Deparse.from(node["relation"])

    cmds = []

    node["cmds"].each do |cmd|
      cmds << PgQuery::Deparse.from(cmd)
    end

    result << cmds.join(', ')

    return result.join(' ')
  end
end
