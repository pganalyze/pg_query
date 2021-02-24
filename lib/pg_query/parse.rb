require 'json'

class PgQuery
  def self.parse(query)
    tree, stderr = _raw_parse(query)

    begin
      tree = JSON.parse(tree, max_nesting: 1000)
    rescue JSON::ParserError
      raise ParseError.new('Failed to parse JSON', __FILE__, __LINE__, -1)
    end

    warnings = []
    stderr.each_line do |line|
      next unless line[/^WARNING/]
      warnings << line.strip
    end

    PgQuery.new(query, tree, warnings)
  end

  attr_reader :query
  attr_reader :tree
  attr_reader :warnings

  def initialize(query, tree, warnings = [])
    @query = query
    @tree = tree
    @warnings = warnings
    @tables = nil
    @aliases = nil
    @cte_names = nil
    @functions = nil
  end

  def tables
    tables_with_types.map { |t| t[:table] }
  end

  def select_tables
    tables_with_types.select { |t| t[:type] == :select }.map { |t| t[:table] }
  end

  def dml_tables
    tables_with_types.select { |t| t[:type] == :dml }.map { |t| t[:table] }
  end

  def ddl_tables
    tables_with_types.select { |t| t[:type] == :ddl }.map { |t| t[:table] }
  end

  # Returns function names, ignoring their argument types. This may be insufficient
  # if you need to disambiguate two functions with the same name but different argument
  # types.
  def functions
    functions_with_types.map { |f| f[:function] }
  end

  def ddl_functions
    functions_with_types.select { |f| f[:type] == :ddl }.map { |f| f[:function] }
  end

  def call_functions
    functions_with_types.select { |f| f[:type] == :call }.map { |f| f[:function] }
  end

  def cte_names
    load_objects! if @cte_names.nil?
    @cte_names
  end

  def aliases
    load_objects! if @aliases.nil?
    @aliases
  end

  def tables_with_types
    load_objects! if @tables.nil?
    @tables
  end

  def functions_with_types
    load_objects! if @functions.nil?
    @functions
  end

  protected

  def load_objects! # rubocop:disable Metrics/CyclomaticComplexity
    @tables = [] # types: select, dml, ddl
    @cte_names = []
    @aliases = {}
    @functions = [] # types: call, ddl

    statements = @tree.dup
    from_clause_items = [] # types: select, dml, ddl
    subselect_items = []

    loop do
      statement = statements.shift
      if statement
        case statement.keys[0]
        when RAW_STMT
          statements << statement[RAW_STMT][STMT_FIELD]
        # The following statement types do not modify tables and are added to from_clause_items
        # (and subsequently @tables)
        when SELECT_STMT
          case statement[SELECT_STMT]['op']
          when 0
            (statement[SELECT_STMT][FROM_CLAUSE_FIELD] || []).each do |item|
              if item[RANGE_SUBSELECT]
                statements << item[RANGE_SUBSELECT]['subquery']
              else
                from_clause_items << { item: item, type: :select }
              end
            end
          when 1
            statements << statement[SELECT_STMT]['larg'] if statement[SELECT_STMT]['larg']
            statements << statement[SELECT_STMT]['rarg'] if statement[SELECT_STMT]['rarg']
          end

          if (with_clause = statement[SELECT_STMT]['withClause'])
            cte_statements, cte_names = statements_and_cte_names_for_with_clause(with_clause)
            @cte_names.concat(cte_names)
            statements.concat(cte_statements)
          end
        # The following statements modify the contents of a table
        when INSERT_STMT, UPDATE_STMT, DELETE_STMT
          value = statement.values[0]
          from_clause_items << { item: value['relation'], type: :dml }
          statements << value['selectStmt'] if value.key?('selectStmt')
          statements << value['withClause'] if value.key?('withClause')

          if (with_clause = value['withClause'])
            cte_statements, cte_names = statements_and_cte_names_for_with_clause(with_clause)
            @cte_names.concat(cte_names)
            statements.concat(cte_statements)
          end
        when COPY_STMT
          from_clause_items << { item: statement.values[0]['relation'], type: :dml } if statement.values[0]['relation']
          statements << statement.values[0]['query']
        # The following statement types are DDL (changing table structure)
        when ALTER_TABLE_STMT, CREATE_STMT
          from_clause_items << { item: statement.values[0]['relation'], type: :ddl }
        when CREATE_TABLE_AS_STMT
          if statement[CREATE_TABLE_AS_STMT]['into'] && statement[CREATE_TABLE_AS_STMT]['into'][INTO_CLAUSE]['rel']
            from_clause_items << { item: statement[CREATE_TABLE_AS_STMT]['into'][INTO_CLAUSE]['rel'], type: :ddl }
          end
          if statement[CREATE_TABLE_AS_STMT]['query']
            statements << statement[CREATE_TABLE_AS_STMT]['query']
          end
        when TRUNCATE_STMT
          from_clause_items += statement.values[0]['relations'].map { |r| { item: r, type: :ddl } }
        when VIEW_STMT
          from_clause_items << { item: statement[VIEW_STMT]['view'], type: :ddl }
          statements << statement[VIEW_STMT]['query']
        when VACUUM_STMT, INDEX_STMT, CREATE_TRIG_STMT, RULE_STMT
          from_clause_items << { item: statement.values[0]['relation'], type: :ddl }
        when REFRESH_MAT_VIEW_STMT
          from_clause_items << { item: statement[REFRESH_MAT_VIEW_STMT]['relation'], type: :ddl }
        when DROP_STMT
          objects = statement[DROP_STMT]['objects'].map do |obj|
            if obj.is_a?(Array)
              obj.map { |obj2| obj2['String'] && obj2['String']['str'] }
            else
              obj['String'] && obj['String']['str']
            end
          end
          case statement[DROP_STMT]['removeType']
          when OBJECT_TYPE_TABLE
            @tables += objects.map { |r| { table: r.join('.'), type: :ddl } }
          when OBJECT_TYPE_RULE, OBJECT_TYPE_TRIGGER
            @tables += objects.map { |r| { table: r[0..-2].join('.'), type: :ddl } }
          when OBJECT_TYPE_FUNCTION
            # Only one function can be dropped in a statement
            obj = statement[DROP_STMT]['objects'][0]['ObjectWithArgs']
            @functions << { function: obj['objname'][0]['String']['str'], type: :ddl }
          end
        when GRANT_STMT
          objects = statement[GRANT_STMT]['objects']
          case statement[GRANT_STMT]['objtype']
          when 0 # Column # rubocop:disable Lint/EmptyWhen
            # FIXME
          when 1 # Table
            from_clause_items += objects.map { |o| { item: o, type: :ddl } }
          when 2 # Sequence # rubocop:disable Lint/EmptyWhen
            # FIXME
          end
        when LOCK_STMT
          from_clause_items += statement.values[0]['relations'].map { |r| { item: r, type: :ddl } }
        # The following are other statements that don't fit into query/DML/DDL
        when EXPLAIN_STMT
          statements << statement[EXPLAIN_STMT]['query']
        when CREATE_FUNCTION_STMT
          @functions << {
            function: statement[CREATE_FUNCTION_STMT]['funcname'][0]['String']['str'],
            type: :ddl
          }
        when RENAME_STMT
          if statement[RENAME_STMT]['renameType'] == OBJECT_TYPE_FUNCTION
            original_name = statement[RENAME_STMT]['object']['ObjectWithArgs']['objname'][0]['String']['str']
            new_name = statement[RENAME_STMT]['newname']
            @functions += [
              { function: original_name, type: :ddl },
              { function: new_name, type: :ddl }
            ]
          end
        end

        statement_value = statement.values[0]
        unless statement.empty?
          subselect_items.concat(statement_value['targetList']) if statement_value['targetList']
          subselect_items << statement_value['whereClause'] if statement_value['whereClause']
          subselect_items.concat(statement_value['sortClause'].collect { |h| h[SORT_BY]['node'] }) if statement_value['sortClause']
          subselect_items.concat(statement_value['groupClause']) if statement_value['groupClause']
          subselect_items << statement_value['havingClause'] if statement_value['havingClause']
        end
      end

      next_item = subselect_items.shift
      if next_item
        case next_item.keys[0]
        when A_EXPR
          %w[lexpr rexpr].each do |side|
            elem = next_item.values[0][side]
            next unless elem
            if elem.is_a?(Array)
              subselect_items += elem
            else
              subselect_items << elem
            end
          end
        when BOOL_EXPR
          subselect_items.concat(next_item.values[0]['args'])
        when RES_TARGET
          subselect_items << next_item[RES_TARGET]['val']
        when SUB_LINK
          statements << next_item[SUB_LINK]['subselect']
        when FUNC_CALL
          @functions << {
            function: next_item[FUNC_CALL]['funcname'][0]['String']['str'],
            type: :call
          }
        end
      end

      break if subselect_items.empty? && statements.empty?
    end

    loop do
      next_item = from_clause_items.shift
      break unless next_item && next_item[:item]

      case next_item[:item].keys[0]
      when JOIN_EXPR
        %w[larg rarg].each do |side|
          from_clause_items << { item: next_item[:item][JOIN_EXPR][side], type: next_item[:type] }
        end
      when ROW_EXPR
        from_clause_items += next_item[:item][ROW_EXPR]['args'].map { |a| { item: a, type: next_item[:type] } }
      when RANGE_VAR
        rangevar = next_item[:item][RANGE_VAR]
        next if !rangevar['schemaname'] && @cte_names.include?(rangevar['relname'])

        table = [rangevar['schemaname'], rangevar['relname']].compact.join('.')
        @tables << { table: table, type: next_item[:type] }
        @aliases[rangevar['alias'][ALIAS]['aliasname']] = table if rangevar['alias']
      when RANGE_SUBSELECT
        from_clause_items << { item: next_item[:item][RANGE_SUBSELECT]['subquery'], type: next_item[:type] }
      when SELECT_STMT
        from_clause = next_item[:item][SELECT_STMT][FROM_CLAUSE_FIELD]
        from_clause_items += from_clause.map { |r| { item: r, type: next_item[:type] } } if from_clause
      end
    end

    @functions.uniq!
    @tables.uniq!
    @cte_names.uniq!
  end

  def statements_and_cte_names_for_with_clause(with_clause)
    statements = []
    cte_names = []

    with_clause[WITH_CLAUSE]['ctes'].each do |item|
      next unless item[COMMON_TABLE_EXPR]
      cte_names << item[COMMON_TABLE_EXPR]['ctename']
      statements << item[COMMON_TABLE_EXPR]['ctequery']
    end

    [statements, cte_names]
  end
end
