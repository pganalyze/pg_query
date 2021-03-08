module PgQuery
  class ParserResult
    def deparse
      PgQuery.deparse(@tree)
    end
  end

  # Reconstruct all of the parsed queries into their original form
  def self.deparse(tree)
    PgQuery.deparse_protobuf(PgQuery::ParseResult.encode(tree)).force_encoding('UTF-8')
  end

  # Convenience method for deparsing a statement of a specific type
  def self.deparse_stmt(stmt)
    deparse(PgQuery::ParseResult.new(version: PG_VERSION_NUM, stmts: [PgQuery::RawStmt.new(stmt: PgQuery::Node.from(stmt))]))
  end

  # Convenience method for deparsing an expression
  def self.deparse_expr(expr)
    deparse_stmt(PgQuery::SelectStmt.new(where_clause: expr, op: :SETOP_NONE)).gsub('SELECT WHERE ', '')
  end
end
