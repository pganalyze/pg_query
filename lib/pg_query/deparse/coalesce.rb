# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::COALESCE
  def self.call(node, context)
    args = []

    node["args"].each do |arg|
      args << PgQuery::Deparse.from(arg)
    end

    return format("COALESCE(%s)", args.join(', '))
  end
end
