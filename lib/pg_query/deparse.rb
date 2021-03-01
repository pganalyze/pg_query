class PgQuery::ParserResult
  # Reconstruct all of the parsed queries into their original form
  def deparse(tree = @tree)
    PgQuery.deparse_protobuf(PgQuery::ParseResult.encode(tree))
  end
end
