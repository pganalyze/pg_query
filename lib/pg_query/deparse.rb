require_relative 'deparse/interval'
require_relative 'deparse/alter_table'
class PgQuery
  # Reconstruct all of the parsed queries into their original form
  def deparse(tree = @tree)
    tree.map do |item|
      Deparse.from(item)
    end.join('; ')
  end

  # rubocop:disable Metrics/ModuleLength
  module Deparse
    extend self

    # Given one element of the PgQuery#parsetree reconstruct it back into the
    # original query.
    def from(item)
      deparse_item(item)
    end

    private

    def deparse_item(item, context = nil) # rubocop:disable Metrics/CyclomaticComplexity
      return if item.nil?
      return item if item.is_a?(Fixnum)

      type = item.keys[0]
      node = item.values[0]

      case type
      when A_EXPR
        case node['kind']
        when AEXPR_OP
          deparse_aexpr(node, context)
        when AEXPR_OP_ANY
          deparse_aexpr_any(node)
        when AEXPR_IN
          deparse_aexpr_in(node)
        when CONSTR_TYPE_FOREIGN
          deparse_aexpr_like(node)
        when AEXPR_BETWEEN, AEXPR_NOT_BETWEEN, AEXPR_BETWEEN_SYM, AEXPR_NOT_BETWEEN_SYM
          deparse_aexpr_between(node)
        else
          fail format("Can't deparse: %s: %s", type, node.inspect)
        end
      when ALIAS
        deparse_alias(node)
      when ALTER_TABLE_STMT
        deparse_alter_table(node)
      when ALTER_TABLE_CMD
        deparse_alter_table_cmd(node)
      when A_ARRAY_EXPR
        deparse_a_arrayexp(node)
      when A_CONST
        deparse_a_const(node)
      when A_INDICES
        deparse_a_indices(node)
      when A_INDIRECTION
        deparse_a_indirection(node)
      when A_STAR
        deparse_a_star(node)
      when A_TRUNCATED
        '...' # pg_query internal
      when BOOL_EXPR
        case node['boolop']
        when BOOL_EXPR_AND
          deparse_bool_expr_and(node)
        when BOOL_EXPR_OR
          deparse_bool_expr_or(node)
        when BOOL_EXPR_NOT
          deparse_bool_expr_not(node)
        end
      when CASE_EXPR
        deparse_case(node)
      when COALESCE_EXPR
        deparse_coalesce(node)
      when COLUMN_DEF
        deparse_columndef(node)
      when COLUMN_REF
        deparse_columnref(node)
      when COMMON_TABLE_EXPR
        deparse_cte(node)
      when CONSTRAINT
        deparse_constraint(node)
      when CREATE_FUNCTION_STMT
        deparse_create_function(node)
      when CREATE_STMT
        deparse_create_table(node)
      when DEF_ELEM
        deparse_defelem(node)
      when DELETE_STMT
        deparse_delete_from(node)
      when DROP_STMT
        deparse_drop(node)
      when FUNC_CALL
        deparse_funccall(node)
      when FUNCTION_PARAMETER
        deparse_functionparameter(node)
      when INSERT_STMT
        deparse_insert_into(node)
      when JOIN_EXPR
        deparse_joinexpr(node)
      when LOCKING_CLAUSE
        deparse_lockingclause(node)
      when NULL_TEST
        deparse_nulltest(node)
      when PARAM_REF
        deparse_paramref(node)
      when RANGE_FUNCTION
        deparse_range_function(node)
      when RANGE_SUBSELECT
        deparse_rangesubselect(node)
      when RANGE_VAR
        deparse_rangevar(node)
      when RENAME_STMT
        deparse_renamestmt(node)
      when RES_TARGET
        deparse_restarget(node, context)
      when ROW_EXPR
        deparse_row(node)
      when SELECT_STMT
        deparse_select(node)
      when SORT_BY
        deparse_sortby(node)
      when SUB_LINK
        deparse_sublink(node)
      when TRANSACTION_STMT
        deparse_transaction(node)
      when TYPE_CAST
        deparse_typecast(node)
      when TYPE_NAME
        deparse_typename(node)
      when UPDATE_STMT
        deparse_update(node)
      when CASE_WHEN
        deparse_when(node)
      when WINDOW_DEF
        deparse_windowdef(node)
      when WITH_CLAUSE
        deparse_with_clause(node)
      when VIEW_STMT
        deparse_viewstmt(node)
      when VARIABLE_SET_STMT
        deparse_variable_set_stmt(node)
      when STRING
        if context == A_CONST
          format("'%s'", node['str'].gsub("'", "''"))
        elsif [FUNC_CALL, TYPE_NAME, :operator, :defname_as].include?(context)
          node['str']
        else
          format('"%s"', node['str'].gsub('"', '""'))
        end
      when INTEGER
        node['ival'].to_s
      when FLOAT
        node['str']
      else
        fail format("Can't deparse: %s: %s", type, node.inspect)
      end
    end

    def deparse_item_list(nodes, context = nil)
      nodes.map { |n| deparse_item(n, context) }
    end

    def deparse_rangevar(node)
      output = []
      output << 'ONLY' if node['inhOpt'] == 0
      output << '"' + node['relname'] + '"'
      output << deparse_item(node['alias']) if node['alias']
      output.join(' ')
    end

    def deparse_renamestmt(node)
      output = []

      if node['renameType'] == OBJECT_TYPE_TABLE
        output << 'ALTER TABLE'
        output << deparse_item(node['relation'])
        output << 'RENAME TO'
        output << node['newname']
      else
        fail format("Can't deparse: %s", node.inspect)
      end

      output.join(' ')
    end

    def deparse_columnref(node)
      node['fields'].map do |field|
        field.is_a?(String) ? '"' + field + '"' : deparse_item(field)
      end.join('.')
    end

    def deparse_a_arrayexp(node)
      'ARRAY[' + node['elements'].map do |element|
        deparse_item(element)
      end.join(', ') + ']'
    end

    def deparse_a_const(node)
      deparse_item(node['val'], A_CONST)
    end

    def deparse_a_star(_node)
      '*'
    end

    def deparse_a_indirection(node)
      output = [deparse_item(node['arg'])]
      node['indirection'].each do |subnode|
        output << deparse_item(subnode)
      end
      output.join
    end

    def deparse_a_indices(node)
      format('[%s]', deparse_item(node['uidx']))
    end

    def deparse_alias(node)
      name = node['aliasname']
      if node['colnames']
        name + '(' + deparse_item_list(node['colnames']).join(', ') + ')'
      else
        name
      end
    end

    def deparse_alter_table(node)
      output = []
      output << 'ALTER TABLE'

      output << deparse_item(node['relation'])

      output << node['cmds'].map do |item|
        deparse_item(item)
      end.join(', ')

      output.join(' ')
    end

    def deparse_alter_table_cmd(node)
      command, options = AlterTable.commands(node)

      output = []
      output << command if command
      output << 'IF EXISTS' if node['missing_ok']
      output << node['name']
      output << options if options
      output << deparse_item(node['def']) if node['def']
      output << 'CASCADE' if node['behavior'] == 1

      output.compact.join(' ')
    end

    def deparse_paramref(node)
      if node['number'].nil?
        '?'
      else
        format('$%d', node['number'])
      end
    end

    def deparse_restarget(node, context)
      if context == :select
        [deparse_item(node['val']), node['name']].compact.join(' AS ')
      elsif context == :update
        [node['name'], deparse_item(node['val'])].compact.join(' = ')
      elsif node['val'].nil?
        node['name']
      else
        fail format("Can't deparse %s in context %s", node.inspect, context)
      end
    end

    def deparse_funccall(node)
      output = []

      # SUM(a, b)
      args = Array(node['args']).map { |arg| deparse_item(arg) }
      # COUNT(*)
      args << '*' if node['agg_star']

      name = (node['funcname'].map { |n| deparse_item(n, FUNC_CALL) } - ['pg_catalog']).join('.')
      distinct = node['agg_distinct'] ? 'DISTINCT ' : ''
      output << format('%s(%s%s)', name, distinct, args.join(', '))
      output << format('OVER (%s)', deparse_item(node['over'])) if node['over']

      output.join(' ')
    end

    def deparse_windowdef(node)
      output = []

      if node['partitionClause']
        output << 'PARTITION BY'
        output << node['partitionClause'].map do |item|
          deparse_item(item)
        end.join(', ')
      end

      if node['orderClause']
        output << 'ORDER BY'
        output << node['orderClause'].map do |item|
          deparse_item(item)
        end.join(', ')
      end

      output.join(' ')
    end

    def deparse_functionparameter(node)
      deparse_item(node['argType'])
    end

    def deparse_aexpr_in(node)
      rexpr = Array(node['rexpr']).map { |arg| deparse_item(arg) }
      operator = node['name'].map { |n| deparse_item(n, :operator) } == ['='] ? 'IN' : 'NOT IN'
      format('%s %s (%s)', deparse_item(node['lexpr']), operator, rexpr.join(', '))
    end

    def deparse_aexpr_like(node)
      value = deparse_item(node['rexpr'])
      operator = node['name'].map { |n| deparse_item(n, :operator) } == ['~~'] ? 'LIKE' : 'NOT LIKE'
      format('%s %s %s', deparse_item(node['lexpr']), operator, value)
    end

    def deparse_bool_expr_not(node)
      format('NOT %s', deparse_item(node['args'][0]))
    end

    def deparse_range_function(node)
      output = []
      output << 'LATERAL' if node['lateral']
      output << deparse_item(node['functions'][0][0]) # FIXME: Needs more test cases
      output << deparse_item(node['alias']) if node['alias']
      output.join(' ')
    end

    def deparse_aexpr(node, context = false)
      output = []
      output << deparse_item(node['lexpr'], context || true)
      output << deparse_item(node['rexpr'], context || true)
      output = output.join(' ' + deparse_item(node['name'][0], :operator) + ' ')
      if context
        # This is a nested expression, add parentheses.
        output = '(' + output + ')'
      end
      output
    end

    def deparse_bool_expr_and(node)
      # Only put parantheses around OR nodes that are inside this one
      node['args'].map do |arg|
        if [BOOL_EXPR_OR].include?(arg.values[0]['boolop'])
          format('(%s)', deparse_item(arg))
        else
          deparse_item(arg)
        end
      end.join(' AND ')
    end

    def deparse_bool_expr_or(node)
      # Put parantheses around AND + OR nodes that are inside
      node['args'].map do |arg|
        if [BOOL_EXPR_AND, BOOL_EXPR_OR].include?(arg.values[0]['boolop'])
          format('(%s)', deparse_item(arg))
        else
          deparse_item(arg)
        end
      end.join(' OR ')
    end

    def deparse_aexpr_any(node)
      output = []
      output << deparse_item(node['lexpr'])
      output << format('ANY(%s)', deparse_item(node['rexpr']))
      output.join(' ' + deparse_item(node['name'][0], :operator) + ' ')
    end

    def deparse_aexpr_between(node)
      between = case node['kind']
                when AEXPR_BETWEEN
                  ' BETWEEN '
                when AEXPR_NOT_BETWEEN
                  ' NOT BETWEEN '
                when AEXPR_BETWEEN_SYM
                  ' BETWEEN SYMMETRIC '
                when AEXPR_NOT_BETWEEN_SYM
                  ' NOT BETWEEN SYMMETRIC '
                end
      name   = deparse_item(node['lexpr'])
      output = node['rexpr'].map { |n| deparse_item(n) }
      name << between << output.join(' AND ')
    end

    def deparse_joinexpr(node)
      output = []
      output << deparse_item(node['larg'])
      output << 'LEFT' if node['jointype'] == 1
      output << 'CROSS' if node['jointype'] == 0 && node['quals'].nil?
      output << 'JOIN'
      output << deparse_item(node['rarg'])

      if node['quals']
        output << 'ON'
        output << deparse_item(node['quals'])
      end

      output.join(' ')
    end

    LOCK_CLAUSE_STRENGTH = {
      LCS_FORKEYSHARE => 'FOR KEY SHARE',
      LCS_FORSHARE => 'FOR SHARE',
      LCS_FORNOKEYUPDATE => 'FOR NO KEY UPDATE',
      LCS_FORUPDATE => 'FOR UPDATE'
    }
    def deparse_lockingclause(node)
      output = []
      output << LOCK_CLAUSE_STRENGTH[node['strength']]
      if node['lockedRels']
        output << 'OF'
        output << node['lockedRels'].map do |item|
          deparse_item(item)
        end.join(', ')
      end
      output.join(' ')
    end

    def deparse_sortby(node)
      output = []
      output << deparse_item(node['node'])
      output << 'ASC' if node['sortby_dir'] == 1
      output << 'DESC' if node['sortby_dir'] == 2
      output.join(' ')
    end

    def deparse_with_clause(node)
      output = ['WITH']
      output << 'RECURSIVE' if node['recursive']
      output << node['ctes'].map do |cte|
        deparse_item(cte)
      end.join(', ')
      output.join(' ')
    end

    def deparse_viewstmt(node)
      output = []
      output << 'CREATE'
      output << 'OR REPLACE' if node['replace']

      persistence = relpersistence(node['view'])
      output << persistence if persistence

      output << 'VIEW'
      output << node['view'][RANGE_VAR]['relname']
      output << format('(%s)', deparse_item_list(node['aliases']).join(', ')) if node['aliases']

      output << 'AS'
      output << deparse_item(node['query'])

      case node['withCheckOption']
      when 1
        output << 'WITH CHECK OPTION'
      when 2
        output << 'WITH CASCADED CHECK OPTION'
      end
      output.join(' ')
    end

    def deparse_variable_set_stmt(node)
      output = []
      output << 'SET'
      output << 'LOCAL' if node['is_local']
      output << node['name']
      output << 'TO'
      output << node['args'].map { |arg| deparse_item(arg) }.join(', ')
      output.join(' ')
    end

    def deparse_cte(node)
      output = []
      output << node['ctename']
      output << format('(%s)', node['aliascolnames'].map { |n| deparse_item(n) }.join(', ')) if node['aliascolnames']
      output << format('AS (%s)', deparse_item(node['ctequery']))
      output.join(' ')
    end

    def deparse_case(node)
      output = ['CASE']
      output += node['args'].map { |arg| deparse_item(arg) }
      if node['defresult']
        output << 'ELSE'
        output << deparse_item(node['defresult'])
      end
      output << 'END'
      output.join(' ')
    end

    def deparse_columndef(node)
      output = [node['colname']]
      output << deparse_item(node['typeName'])
      if node['raw_default']
        output << 'USING'
        output << deparse_item(node['raw_default'])
      end
      if node['constraints']
        output += node['constraints'].map do |item|
          deparse_item(item)
        end
      end
      output.compact.join(' ')
    end

    def deparse_constraint(node) # rubocop:disable Metrics/CyclomaticComplexity
      output = []
      if node['conname']
        output << 'CONSTRAINT'
        output << node['conname']
      end
      case node['contype']
      when CONSTR_TYPE_NULL
        output << 'NULL'
      when CONSTR_TYPE_NOTNULL
        output << 'NOT NULL'
      when CONSTR_TYPE_DEFAULT
        output << 'DEFAULT'
      when CONSTR_TYPE_CHECK
        output << 'CHECK'
      when CONSTR_TYPE_PRIMARY
        output << 'PRIMARY KEY'
      when CONSTR_TYPE_UNIQUE
        output << 'UNIQUE'
      when CONSTR_TYPE_EXCLUSION
        output << 'EXCLUSION'
      when CONSTR_TYPE_FOREIGN
        output << 'FOREIGN KEY'
      end

      if node['raw_expr']
        expression = deparse_item(node['raw_expr'])
        # Unless it's simple, put parentheses around it
        expression = '(' + expression + ')' if node['raw_expr'][A_EXPR] && node['raw_expr'][A_EXPR]['kind'] == AEXPR_OP
        output << expression
      end
      output << '(' + deparse_item_list(node['keys']).join(', ') + ')' if node['keys']
      output << '(' + deparse_item_list(node['fk_attrs']).join(', ') + ')' if node['fk_attrs']
      output << 'REFERENCES ' + deparse_item(node['pktable']) + ' (' + deparse_item_list(node['pk_attrs']).join(', ') + ')' if node['pktable']
      output << 'NOT VALID' if node['skip_validation']
      output << "USING INDEX #{node['indexname']}" if node['indexname']
      output.join(' ')
    end

    def deparse_create_function(node)
      output = []
      output << 'CREATE'
      output << 'OR REPLACE' if node['replace']
      output << 'FUNCTION'

      arguments = deparse_item_list(node['parameters']).join(', ')

      output << deparse_item_list(node['funcname']).join('.') + '(' + arguments + ')'

      output << 'RETURNS'
      output << deparse_item(node['returnType'])
      output += node['options'].map { |item| deparse_item(item) }

      output.join(' ')
    end

    def deparse_create_table(node)
      output = []
      output << 'CREATE'

      persistence = relpersistence(node['relation'])
      output << persistence if persistence

      output << 'TABLE'

      output << 'IF NOT EXISTS' if node['if_not_exists']

      output << deparse_item(node['relation'])

      output << '(' + node['tableElts'].map do |item|
        deparse_item(item)
      end.join(', ') + ')'

      if node['inhRelations']
        output << 'INHERITS'
        output << '(' + node['inhRelations'].map do |relation|
          deparse_item(relation)
        end.join(', ') + ')'
      end

      output.join(' ')
    end

    def deparse_when(node)
      output = ['WHEN']
      output << deparse_item(node['expr'])
      output << 'THEN'
      output << deparse_item(node['result'])
      output.join(' ')
    end

    def deparse_sublink(node)
      if node['subLinkType'] == SUBLINK_TYPE_ANY
        return format('%s IN (%s)', deparse_item(node['testexpr']), deparse_item(node['subselect']))
      elsif node['subLinkType'] == SUBLINK_TYPE_EXISTS
        return format('EXISTS(%s)', deparse_item(node['subselect']))
      else
        return format('(%s)', deparse_item(node['subselect']))
      end
    end

    def deparse_rangesubselect(node)
      output = '(' + deparse_item(node['subquery']) + ')'
      if node['alias']
        output + ' ' + deparse_item(node['alias'])
      else
        output
      end
    end

    def deparse_row(node)
      'ROW(' + node['args'].map { |arg| deparse_item(arg) }.join(', ') + ')'
    end

    def deparse_select(node) # rubocop:disable Metrics/CyclomaticComplexity
      output = []

      if node['op'] == 1
        output << deparse_item(node['larg'])
        output << 'UNION'
        output << 'ALL' if node['all']
        output << deparse_item(node['rarg'])
        return output.join(' ')
      end

      output << deparse_item(node['withClause']) if node['withClause']

      if node[TARGET_LIST_FIELD]
        output << 'SELECT'
        output << node[TARGET_LIST_FIELD].map do |item|
          deparse_item(item, :select)
        end.join(', ')
      end

      if node[FROM_CLAUSE_FIELD]
        output << 'FROM'
        output << node[FROM_CLAUSE_FIELD].map do |item|
          deparse_item(item)
        end.join(', ')
      end

      if node['whereClause']
        output << 'WHERE'
        output << deparse_item(node['whereClause'])
      end

      if node['valuesLists']
        output << 'VALUES'
        output << node['valuesLists'].map do |value_list|
          '(' + value_list.map { |v| deparse_item(v) }.join(', ') + ')'
        end.join(', ')
      end

      if node['groupClause']
        output << 'GROUP BY'
        output << node['groupClause'].map do |item|
          deparse_item(item)
        end.join(', ')
      end

      if node['havingClause']
        output << 'HAVING'
        output << deparse_item(node['havingClause'])
      end

      if node['sortClause']
        output << 'ORDER BY'
        output << node['sortClause'].map do |item|
          deparse_item(item)
        end.join(', ')
      end

      if node['limitCount']
        output << 'LIMIT'
        output << deparse_item(node['limitCount'])
      end

      if node['limitOffset']
        output << 'OFFSET'
        output << deparse_item(node['limitOffset'])
      end

      if node['lockingClause']
        node['lockingClause'].map do |item|
          output << deparse_item(item)
        end
      end

      output.join(' ')
    end

    def deparse_insert_into(node)
      output = []
      output << deparse_item(node['withClause']) if node['withClause']

      output << 'INSERT INTO'
      output << deparse_item(node['relation'])

      if node['cols']
        output << '(' + node['cols'].map do |column|
          deparse_item(column)
        end.join(', ') + ')'
      end

      output << deparse_item(node['selectStmt'])

      output.join(' ')
    end

    def deparse_update(node)
      output = []
      output << deparse_item(node['withClause']) if node['withClause']

      output << 'UPDATE'
      output << deparse_item(node['relation'])

      if node[TARGET_LIST_FIELD]
        output << 'SET'
        node[TARGET_LIST_FIELD].each do |item|
          output << deparse_item(item, :update)
        end
      end

      if node['whereClause']
        output << 'WHERE'
        output << deparse_item(node['whereClause'])
      end

      if node['returningList']
        output << 'RETURNING'
        output << node['returningList'].map do |item|
          # RETURNING is formatted like a SELECT
          deparse_item(item, :select)
        end.join(', ')
      end

      output.join(' ')
    end

    def deparse_typecast(node)
      if deparse_item(node['typeName']) == 'boolean'
        deparse_item(node['arg']) == "'t'" ? 'true' : 'false'
      else
        deparse_item(node['arg']) + '::' + deparse_typename(node['typeName'][TYPE_NAME])
      end
    end

    def deparse_typename(node)
      names = node['names'].map { |n| deparse_item(n, TYPE_NAME) }

      # Intervals are tricky and should be handled in a separate method because
      # they require performing some bitmask operations.
      return deparse_interval_type(node) if names == %w(pg_catalog interval)

      output = []
      output << 'SETOF' if node['setof']

      if node['typmods']
        arguments = node['typmods'].map do |item|
          deparse_item(item)
        end.join(', ')
      end
      output << deparse_typename_cast(names, arguments)

      output.join(' ')
    end

    def deparse_typename_cast(names, arguments) # rubocop:disable Metrics/CyclomaticComplexity
      catalog, type = names
      # Just pass along any custom types.
      # (The pg_catalog types are built-in Postgres system types and are
      #  handled in the case statement below)
      return names.join('.') if catalog != 'pg_catalog'

      case type
      when 'bpchar'
        # char(2) or char(9)
        "char(#{arguments})"
      when 'varchar'
        "varchar(#{arguments})"
      when 'numeric'
        # numeric(3, 5)
        "numeric(#{arguments})"
      when 'bool'
        'boolean'
      when 'int2'
        'smallint'
      when 'int4'
        'int'
      when 'int8'
        'bigint'
      when 'real', 'float4'
        'real'
      when 'float8'
        'double'
      when 'time'
        'time'
      when 'timetz'
        'time with time zone'
      when 'timestamp'
        'timestamp'
      when 'timestamptz'
        'timestamp with time zone'
      else
        fail format("Can't deparse type: %s", type)
      end
    end

    # Deparses interval type expressions like `interval year to month` or
    # `interval hour to second(5)`
    def deparse_interval_type(node)
      type = ['interval']

      if node['typmods']
        typmods = node['typmods'].map { |typmod| deparse_item(typmod) }
        type << Interval.from_int(typmods.first.to_i).map do |part|
          # only the `second` type can take an argument.
          if part == 'second' && typmods.size == 2
            "second(#{typmods.last})"
          else
            part
          end.downcase
        end.join(' to ')
      end

      type.join(' ')
    end

    def deparse_nulltest(node)
      output = [deparse_item(node['arg'])]
      if node['nulltesttype'] == 0
        output << 'IS NULL'
      elsif node['nulltesttype'] == 1
        output << 'IS NOT NULL'
      end
      output.join(' ')
    end

    TRANSACTION_CMDS = {
      TRANS_STMT_BEGIN => 'BEGIN',
      TRANS_STMT_COMMIT => 'COMMIT',
      TRANS_STMT_ROLLBACK => 'ROLLBACK',
      TRANS_STMT_SAVEPOINT => 'SAVEPOINT',
      TRANS_STMT_RELEASE => 'RELEASE',
      TRANS_STMT_ROLLBACK_TO => 'ROLLBACK TO SAVEPOINT'
    }
    def deparse_transaction(node)
      output = []
      output << TRANSACTION_CMDS[node['kind']] || fail(format("Can't deparse TRANSACTION %s", node.inspect))

      if node['options']
        output += node['options'].map { |item| deparse_item(item) }
      end

      output.join(' ')
    end

    def deparse_coalesce(node)
      format('COALESCE(%s)', node['args'].map { |a| deparse_item(a) }.join(', '))
    end

    def deparse_defelem(node)
      case node['defname']
      when 'as'
        "AS $$#{deparse_item_list(node['arg'], :defname_as).join("\n")}$$"
      when 'language'
        "language #{deparse_item(node['arg'])}"
      when 'volatility'
        node['arg']['String']['str'].upcase # volatility does not need to be quoted
      when 'strict'
        deparse_item(node['arg']) == '1' ? 'RETURNS NULL ON NULL INPUT' : 'CALLED ON NULL INPUT'
      else
        deparse_item(node['arg'])
      end
    end

    def deparse_delete_from(node)
      output = []
      output << deparse_item(node['withClause']) if node['withClause']

      output << 'DELETE FROM'
      output << deparse_item(node['relation'])

      if node['usingClause']
        output << 'USING'
        output << node['usingClause'].map do |item|
          deparse_item(item)
        end.join(', ')
      end

      if node['whereClause']
        output << 'WHERE'
        output << deparse_item(node['whereClause'])
      end

      if node['returningList']
        output << 'RETURNING'
        output << node['returningList'].map do |item|
          # RETURNING is formatted like a SELECT
          deparse_item(item, :select)
        end.join(', ')
      end

      output.join(' ')
    end

    def deparse_drop(node)
      output = ['DROP']
      output << 'TABLE' if node['removeType'] == OBJECT_TYPE_TABLE
      output << 'CONCURRENTLY' if node['concurrent']
      output << 'IF EXISTS' if node['missing_ok']

      output << node['objects'].map { |list| list.map { |object| deparse_item(object) } }.join(', ')

      output << 'CASCADE' if node['behavior'] == 1

      output.join(' ')
    end

    # The PG parser adds several pieces of view data onto the RANGEVAR
    # that need to be printed before deparse_rangevar is called.
    def relpersistence(rangevar)
      if rangevar[RANGE_VAR]['relpersistence'] == 't'
        'TEMPORARY'
      elsif rangevar[RANGE_VAR]['relpersistence'] == 'u'
        'UNLOGGED'
      end
    end
  end
end
