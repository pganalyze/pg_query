module PgQuery
  class ParserResult
    def deparse(opts: nil)
      PgQuery.deparse(@tree, opts: opts)
    end
  end

  class DeparseComment
    attr_accessor :match_location, :newlines_before_comment, :newlines_after_comment, :str
  end

  DeparseOpts = Struct.new(:pretty_print, :comments, :indent_size, :max_line_length,
                           :trailing_newline, :commas_start_of_line, keyword_init: true)

  # Reconstruct all of the parsed queries into their original form
  def self.deparse(tree, opts: nil)
    protobuf_encoded = if PgQuery::ParseResult.method(:encode).arity == 1
                         PgQuery::ParseResult.encode(tree)
                       elsif PgQuery::ParseResult.method(:encode).arity == -1
                         PgQuery::ParseResult.encode(tree, recursion_limit: 1_000)
                       else
                         raise ArgumentError, 'Unsupported protobuf Ruby API'
                       end

    if opts
      PgQuery.deparse_protobuf_opts(
        protobuf_encoded,
        opts.pretty_print,
        opts.comments || [],
        opts.indent_size || 0,
        opts.max_line_length || 0,
        opts.trailing_newline,
        opts.commas_start_of_line
      ).force_encoding('UTF-8')
    else
      PgQuery.deparse_protobuf(protobuf_encoded).force_encoding('UTF-8')
    end
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
