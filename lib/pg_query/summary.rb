module PgQuery
  # Parses the given SQL statement and returns a summary of it.
  #
  # It is possible to gather the same information using PgQuery.parse and
  # walking the parse tree, but summary does this work in C, and only sends
  # the summarized information over protobuf. Avoiding sending the full parse
  # tree over protobuf can be significantly faster for large queries.
  #
  # Note that truncation happens on the C side, and so the maximum length has
  # to be passed in ahead of time. summary(query, truncate_limit: 100).truncated_query
  # is the equivalent of parse(query).truncate(100).
  def self.summary(query, truncate_limit: -1)
    result, stderr = _raw_summary(query, truncate_limit)

    begin
      result = PgQuery::SummaryResult.decode(result)
    rescue Google::Protobuf::ParseError => e
      raise PgQuery::ParseError.new(format('Failed to parse summary: %s', e.message), __FILE__, __LINE__, -1)
    end

    warnings = []
    stderr.each_line do |line|
      next unless line[/^WARNING/]
      warnings << line.strip
    end

    PgQuery::SummaryParserResult.new(query, result, warnings, truncate_limit)
  end

  # Result of PgQuery.summary.
  #
  # Where possible this is API compatible with ParserResult, with these caveats:
  #
  # - tables_with_details omits the location, inh and relpersistence values that
  #   ParserResult reports, since the summary does not carry them
  # - filter_columns only covers the WHERE clause of SELECT statements, so unlike
  #   ParserResult#filter_columns it does not include JOIN conditions, or the WHERE
  #   clause of UPDATE/DELETE statements
  # - functions_with_details additionally returns the schema name and the bare
  #   function name, which ParserResult does not provide
  # - statement_types has no ParserResult equivalent, returns the statement types of
  #   the query, e.g. ["SelectStmt"]
  # - truncated_query is offered instead of ParserResult#truncate(max_length), since
  #   truncation has already happened when the result is returned - it returns nil if
  #   no truncate_limit was passed to PgQuery.summary
  #
  # The underlying protobuf message is available through #protobuf.
  class SummaryParserResult
    attr_reader :query, :protobuf, :warnings

    def initialize(query, protobuf, warnings = [], truncate_limit = -1)
      @query = query
      @protobuf = protobuf
      @warnings = warnings
      @truncate_limit = truncate_limit
    end

    def tables
      tables_with_details.map { |t| t[:name] }.uniq
    end

    def select_tables
      tables_with_details.select { |t| t[:type] == :select }.map { |t| t[:name] }.uniq
    end

    def dml_tables
      tables_with_details.select { |t| t[:type] == :dml }.map { |t| t[:name] }.uniq
    end

    def ddl_tables
      tables_with_details.select { |t| t[:type] == :ddl }.map { |t| t[:name] }.uniq
    end

    def functions
      functions_with_details.map { |f| f[:function] }.uniq
    end

    def ddl_functions
      functions_with_details.select { |f| f[:type] == :ddl }.map { |f| f[:function] }.uniq
    end

    def call_functions
      functions_with_details.select { |f| f[:type] == :call }.map { |f| f[:function] }.uniq
    end

    def cte_names
      @cte_names ||= @protobuf.cte_names.to_a.uniq
    end

    def aliases
      @aliases ||= @protobuf.aliases.to_h
    end

    def tables_with_details
      @tables_with_details ||= @protobuf.tables.map do |table|
        {
          name: table.name,
          type: context_to_type(table.context),
          schemaname: (table.schema_name unless table.schema_name.empty?),
          relname: table.table_name
        }
      end.uniq
    end

    def functions_with_details
      @functions_with_details ||= @protobuf.functions.map do |function|
        {
          function: function.name,
          type: context_to_type(function.context),
          schemaname: (function.schema_name unless function.schema_name.empty?),
          funcname: function.function_name
        }
      end.uniq
    end

    def filter_columns
      @filter_columns ||= @protobuf.filter_columns.map do |filter_column|
        table = [filter_column.schema_name, filter_column.table_name].reject(&:empty?).join('.')
        table = nil if table.empty?
        [aliases[table] || table, filter_column.column]
      end.uniq
    end

    def statement_types
      @statement_types ||= @protobuf.statement_types.to_a
    end

    def truncated_query
      @protobuf.truncated_query unless @truncate_limit == -1
    end

    private

    CONTEXT_TYPES = {
      Select: :select,
      DML: :dml,
      DDL: :ddl,
      Call: :call
    }.freeze

    def context_to_type(context)
      CONTEXT_TYPES[context]
    end
  end
end
