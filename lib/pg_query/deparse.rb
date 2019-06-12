require_relative 'deparse/alter_table'
require_relative 'deparse/interval'
require_relative 'deparse/keywords'

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
      return item if item.is_a?(Integer)

      type = item.keys[0]
      node = item.values[0]

      case type
      when A_EXPR
        case node['kind']
        when AEXPR_OP
          deparse_aexpr(node, context)
        when AEXPR_OP_ALL
          deparse_aexpr_all(node)
        when AEXPR_OP_ANY
          deparse_aexpr_any(node)
        when AEXPR_IN
          deparse_aexpr_in(node)
        when AEXPR_ILIKE
          deparse_aexpr_ilike(node)
        when CONSTR_TYPE_FOREIGN
          deparse_aexpr_like(node)
        when AEXPR_BETWEEN, AEXPR_NOT_BETWEEN, AEXPR_BETWEEN_SYM, AEXPR_NOT_BETWEEN_SYM
          deparse_aexpr_between(node)
        when AEXPR_NULLIF
          deparse_aexpr_nullif(node)
        else
          raise format("Can't deparse: %s: %s", type, node.inspect)
        end
      when ACCESS_PRIV
        deparse_access_priv(node)
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
      when BOOLEAN_TEST
        deparse_boolean_test(node)
      when CASE_EXPR
        deparse_case(node)
      when COALESCE_EXPR
        deparse_coalesce(node)
      when COLLATE_CLAUSE
        deparse_collate(node)
      when COLUMN_DEF
        deparse_columndef(node)
      when COLUMN_REF
        deparse_columnref(node)
      when COMMON_TABLE_EXPR
        deparse_cte(node)
      when COMPOSITE_TYPE_STMT
        deparse_composite_type(node)
      when CONSTRAINT
        deparse_constraint(node)
      when COPY_STMT
        deparse_copy(node)
      when CREATE_CAST_STMT
        deparse_create_cast(node)
      when CREATE_DOMAIN_STMT
        deparse_create_domain(node)
      when CREATE_ENUM_STMT
        deparse_create_enum(node)
      when CREATE_FUNCTION_STMT
        deparse_create_function(node)
      when CREATE_RANGE_STMT
        deparse_create_range(node)
      when CREATE_SCHEMA_STMT
        deparse_create_schema(node)
      when CREATE_STMT
        deparse_create_table(node)
      when CREATE_TABLE_AS_STMT
        deparse_create_table_as(node)
      when INTO_CLAUSE
        deparse_into_clause(node)
      when DEF_ELEM
        deparse_defelem(node)
      when DEFINE_STMT
        deparse_define_stmt(node)
      when DELETE_STMT
        deparse_delete_from(node)
      when DISCARD_STMT
        deparse_discard(node)
      when DROP_STMT
        deparse_drop(node)
      when EXPLAIN_STMT
        deparse_explain(node)
      when FUNC_CALL
        deparse_funccall(node)
      when FUNCTION_PARAMETER
        deparse_functionparameter(node)
      when GRANT_ROLE_STMT
        deparse_grant_role(node)
      when GRANT_STMT
        deparse_grant(node)
      when INSERT_STMT
        deparse_insert_into(node)
      when JOIN_EXPR
        deparse_joinexpr(node)
      when LOCK_STMT
        deparse_lock(node)
      when LOCKING_CLAUSE
        deparse_lockingclause(node)
      when NULL_TEST
        deparse_nulltest(node)
      when OBJECT_WITH_ARGS
        deparse_object_with_args(node)
      when PARAM_REF
        deparse_paramref(node)
      when RANGE_FUNCTION
        deparse_range_function(node)
      when RANGE_SUBSELECT
        deparse_rangesubselect(node)
      when RANGE_VAR
        deparse_rangevar(node)
      when RAW_STMT
        deparse_raw_stmt(node)
      when RENAME_STMT
        deparse_renamestmt(node)
      when RES_TARGET
        deparse_restarget(node, context)
      when ROLE_SPEC
        deparse_role_spec(node)
      when ROW_EXPR
        deparse_row(node)
      when SELECT_STMT
        deparse_select(node)
      when SQL_VALUE_FUNCTION
        deparse_sql_value_function(node)
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
      when VACUUM_STMT
        deparse_vacuum_stmt(node)
      when DO_STMT
        deparse_do_stmt(node)
      when STRING
        if context == A_CONST
          format("'%s'", node['str'].gsub("'", "''"))
        elsif [FUNC_CALL, TYPE_NAME, :operator, :defname_as].include?(context)
          node['str']
        else
          deparse_identifier(node['str'], escape_always: true)
        end
      when INTEGER
        node['ival'].to_s
      when FLOAT
        node['str']
      when NULL
        'NULL'
      else
        raise format("Can't deparse: %s: %s", type, node.inspect)
      end
    end

    def deparse_item_list(nodes, context = nil)
      nodes.map { |n| deparse_item(n, context) }
    end

    def deparse_identifier(ident, escape_always: false)
      return if ident.nil?
      if escape_always || !ident[/^\w+$/] || KEYWORDS.include?(ident.upcase)
        format('"%s"', ident.gsub('"', '""'))
      else
        ident
      end
    end

    def deparse_rangevar(node)
      output = []
      output << 'ONLY' unless node['inh']
      schema = node['schemaname'] ? '"' + node['schemaname'] + '".' : ''
      output << schema + '"' + node['relname'] + '"'
      output << deparse_item(node['alias']) if node['alias']
      output.join(' ')
    end

    def deparse_raw_stmt(node)
      deparse_item(node[STMT_FIELD])
    end

    def deparse_renamestmt(node)
      output = []

      case node['renameType']
      when OBJECT_TYPE_TABLE
        output << 'ALTER TABLE'
        output << deparse_item(node['relation'])
        output << 'RENAME TO'
        output << node['newname']
      else
        raise format("Can't deparse: %s", node.inspect)
      end

      output.join(' ')
    end

    def deparse_columnref(node)
      node['fields'].map do |field|
        field.is_a?(String) ? '"' + field + '"' : deparse_item(field)
      end.join('.')
    end

    def deparse_a_arrayexp(node)
      'ARRAY[' + (node['elements'] || []).map do |element|
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
      output = []
      arg = deparse_item(node['arg'])
      output << if node['arg'].key?(FUNC_CALL)
                  "(#{arg})."
                else
                  arg
                end
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
        deparse_identifier(name)
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

    def deparse_object_with_args(node)
      output = []
      output += node['objname'].map(&method(:deparse_item))
      unless node['args_unspecified']
        args = node.fetch('objargs', []).map(&method(:deparse_item)).join(', ')
        output << "(#{args})"
      end
      output.join('')
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
        [deparse_item(node['val']), deparse_identifier(node['name'])].compact.join(' AS ')
      elsif context == :update
        [node['name'], deparse_item(node['val'])].compact.join(' = ')
      elsif node['val'].nil?
        node['name']
      else
        raise format("Can't deparse %s in context %s", node.inspect, context)
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

    def deparse_grant_role(node)
      output = ['GRANT']
      output << node['granted_roles'].map(&method(:deparse_item)).join(', ')
      output << 'TO'
      output << node['grantee_roles'].map(&method(:deparse_item)).join(', ')
      output << 'WITH ADMIN OPTION' if node['admin_opt']
      output.join(' ')
    end

    def deparse_grant(node) # rubocop:disable Metrics/CyclomaticComplexity
      objtype, allow_all = deparse_grant_objtype(node)
      output = ['GRANT']
      output << if node.key?('privileges')
                  node['privileges'].map(&method(:deparse_item)).join(', ')
                else
                  'ALL'
                end
      output << 'ON'
      objects = node['objects']
      objects = objects[0] if %w[DOMAIN TYPE].include?(objtype)
      objects = objects.map do |object|
        deparsed = deparse_item(object)
        if object.key?(RANGE_VAR) || object.key?(OBJECT_WITH_ARGS) || !allow_all
          objtype == 'TABLE' ? deparsed : "#{objtype} #{deparsed}"
        else
          "ALL #{objtype}S IN SCHEMA #{deparsed}"
        end
      end
      output << objects.join(', ')
      output << 'TO'
      output << node['grantees'].map(&method(:deparse_item)).join(', ')
      output << 'WITH GRANT OPTION' if node['grant_option']
      output.join(' ')
    end

    def deparse_grant_objtype(node)
      {
        1 => ['TABLE', true],
        2 => ['SEQUENCE', true],
        3 => ['DATABASE', false],
        4 => ['DOMAIN', false],
        5 => ['FOREIGN DATA WRAPPER', false],
        6 => ['FOREIGN SERVER', false],
        7 => ['FUNCTION', true],
        8 => ['LANGUAGE', false],
        9 => ['LARGE OBJECT', false],
        10 => ['SCHEMA', false],
        11 => ['TABLESPACE', false],
        12 => ['TYPE', false]
      }.fetch(node['objtype'])
    end

    def deparse_access_priv(node)
      output = [node['priv_name']]
      output << "(#{node['cols'].map(&method(:deparse_item)).join(', ')})" if node.key?('cols')
      output.join(' ')
    end

    def deparse_role_spec(node)
      return 'CURRENT_USER' if node['roletype'] == 1
      return 'SESSION_USER' if node['roletype'] == 2
      return 'PUBLIC' if node['roletype'] == 3
      deparse_identifier(node['rolename'], escape_always: true)
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

    def deparse_aexpr_ilike(node)
      value = deparse_item(node['rexpr'])
      operator = node['name'][0]['String']['str'] == '~~*' ? 'ILIKE' : 'NOT ILIKE'
      format('%s %s %s', deparse_item(node['lexpr']), operator, value)
    end

    def deparse_bool_expr_not(node)
      format('NOT %s', deparse_item(node['args'][0]))
    end

    BOOLEAN_TEST_TYPE_TO_STRING = {
      BOOLEAN_TEST_TRUE        => ' IS TRUE',
      BOOLEAN_TEST_NOT_TRUE    => ' IS NOT TRUE',
      BOOLEAN_TEST_FALSE       => ' IS FALSE',
      BOOLEAN_TEST_NOT_FALSE   => ' IS NOT FALSE',
      BOOLEAN_TEST_UNKNOWN     => ' IS UNKNOWN',
      BOOLEAN_TEST_NOT_UNKNOWN => ' IS NOT UNKNOWN'
    }.freeze
    def deparse_boolean_test(node)
      deparse_item(node['arg']) + BOOLEAN_TEST_TYPE_TO_STRING[node['booltesttype']]
    end

    def deparse_range_function(node)
      output = []
      output << 'LATERAL' if node['lateral']
      output << deparse_item(node['functions'][0][0]) # FIXME: Needs more test cases
      output << deparse_item(node['alias']) if node['alias']
      output << "#{node['alias'] ? '' : 'AS '}(#{deparse_item_list(node['coldeflist']).join(', ')})" if node['coldeflist']
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

    def deparse_aexpr_all(node)
      output = []
      output << deparse_item(node['lexpr'])
      output << format('ALL(%s)', deparse_item(node['rexpr']))
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

    def deparse_aexpr_nullif(node)
      lexpr = deparse_item(node['lexpr'])
      rexpr = deparse_item(node['rexpr'])
      format('NULLIF(%s, %s)', lexpr, rexpr)
    end

    def deparse_joinexpr(node) # rubocop:disable Metrics/CyclomaticComplexity
      output = []
      output << deparse_item(node['larg'])
      case node['jointype']
      when 0
        if node['isNatural']
          output << 'NATURAL'
        elsif node['quals'].nil? && node['usingClause'].nil?
          output << 'CROSS'
        end
      when 1
        output << 'LEFT'
      when 2
        output << 'FULL'
      when 3
        output << 'RIGHT'
      end
      output << 'JOIN'
      output << deparse_item(node['rarg'])

      if node['quals']
        output << 'ON'
        output << deparse_item(node['quals'])
      end

      output << format('USING (%s)', node['usingClause'].map { |n| deparse_item(n) }.join(', ')) if node['usingClause']

      output.join(' ')
    end

    def deparse_lock(node)
      output = []
      output << 'LOCK TABLE'
      tables = node['relations'].map { |table| deparse_item(table) }
      output << tables.join(', ')
      output.join(' ')
    end

    LOCK_CLAUSE_STRENGTH = {
      LCS_FORKEYSHARE => 'FOR KEY SHARE',
      LCS_FORSHARE => 'FOR SHARE',
      LCS_FORNOKEYUPDATE => 'FOR NO KEY UPDATE',
      LCS_FORUPDATE => 'FOR UPDATE'
    }.freeze
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
      output << 'NULLS FIRST' if node['sortby_nulls'] == 1
      output << 'NULLS LAST' if node['sortby_nulls'] == 2
      output.join(' ')
    end

    def deparse_collate(node)
      output = []
      output << deparse_item(node['arg'])
      output << 'COLLATE'
      output << deparse_item_list(node['collname'])
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

    def deparse_vacuum_stmt(node)
      output = []
      output << 'VACUUM'
      output.concat(deparse_vacuum_options(node))
      output << deparse_item(node['relation']) if node.key?('relation')
      if node.key?('va_cols')
        output << "(#{node['va_cols'].map(&method(:deparse_item)).join(', ')})"
      end
      output.join(' ')
    end

    def deparse_vacuum_options(node)
      output = []
      output << 'FULL' if node['options'][4] == 1
      output << 'FREEZE' if node['options'][3] == 1
      output << 'VERBOSE' if node['options'][2] == 1
      output << 'ANALYZE' if node['options'][1] == 1
      output
    end

    def deparse_do_stmt(node)
      output = []
      output << 'DO'
      statement, *rest = node['args']
      output << "$$#{statement['DefElem']['arg']['String']['str']}$$"
      output += rest.map { |item| deparse_item(item) }
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
      output << deparse_item(node['arg']) if node['arg']
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
      if node['collClause']
        output << 'COLLATE'
        output += node['collClause']['CollateClause']['collname'].map(&method(:deparse_item))
      end
      output.compact.join(' ')
    end

    def deparse_composite_type(node)
      output = ['CREATE TYPE']
      output << deparse_rangevar(node['typevar'][RANGE_VAR].merge('inh' => true))
      output << 'AS'
      coldeflist = node['coldeflist'].map(&method(:deparse_item))
      output << "(#{coldeflist.join(', ')})"
      output.join(' ')
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
        expression = '(' + expression + ')' if node['raw_expr'][BOOL_EXPR]
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

    def deparse_copy(node)
      output = ['COPY']
      if node.key?('relation')
        output << deparse_item(node['relation'])
      elsif node.key?('query')
        output << "(#{deparse_item(node['query'])})"
      end
      columns = node.fetch('attlist', []).map { |column| deparse_item(column) }
      output << "(#{columns.join(', ')})" unless columns.empty?
      output << (node['is_from'] ? 'FROM' : 'TO')
      output << 'PROGRAM' if node['is_program']
      output << deparse_copy_output(node)
      output.join(' ')
    end

    def deparse_copy_output(node)
      return "'#{node['filename']}'" if node.key?('filename')
      return 'STDIN' if node['is_from']
      'STDOUT'
    end

    def deparse_create_enum(node)
      output = ['CREATE TYPE']
      output << deparse_item(node['typeName'][0])
      output << 'AS ENUM'
      vals = node['vals'].map { |val| deparse_item(val, A_CONST) }
      output << "(#{vals.join(', ')})"
      output.join(' ')
    end

    def deparse_create_cast(node)
      output = []
      output << 'CREATE'
      output << 'CAST'
      output << format('(%s AS %s)', deparse_item(node['sourcetype']), deparse_item(node['targettype']))
      output << if node['func']
                  function = node['func']['ObjectWithArgs']
                  name = deparse_item_list(function['objname']).join('.')
                  arguments = deparse_item_list(function['objargs']).join(', ')
                  format('WITH FUNCTION %s(%s)', name, arguments)
                elsif node['inout']
                  'WITH INOUT'
                else
                  'WITHOUT FUNCTION'
                end
      output << 'AS IMPLICIT' if (node['context']).zero?
      output << 'AS ASSIGNMENT' if node['context'] == 1
      output.join(' ')
    end

    def deparse_create_domain(node)
      output = []
      output << 'CREATE'
      output << 'DOMAIN'
      output << deparse_item_list(node['domainname']).join('.')
      output << 'AS'
      output << deparse_item(node['typeName']) if node['typeName']
      output << deparse_item(node['collClause']) if node['collClause']
      output << deparse_item_list(node['constraints'])
      output.join(' ')
    end

    def deparse_create_function(node)
      output = []
      output << 'CREATE'
      output << 'OR REPLACE' if node['replace']
      output << 'FUNCTION'

      arguments = deparse_item_list(node.fetch('parameters', [])).join(', ')

      output << deparse_item_list(node['funcname']).join('.') + '(' + arguments + ')'

      output << 'RETURNS'
      output << deparse_item(node['returnType'])
      output += node['options'].map { |item| deparse_item(item) }

      output.join(' ')
    end

    def deparse_create_range(node)
      output = ['CREATE TYPE']
      output << deparse_item(node['typeName'][0])
      output << 'AS RANGE'
      params = node['params'].map do |param|
        param_out = [param['DefElem']['defname']]
        if param['DefElem'].key?('arg')
          param_out << deparse_item(param['DefElem']['arg'])
        end
        param_out.join('=')
      end
      output << "(#{params.join(', ')})"
      output.join(' ')
    end

    def deparse_create_schema(node)
      output = ['CREATE SCHEMA']
      output << 'IF NOT EXISTS' if node['if_not_exists']
      output << deparse_identifier(node['schemaname']) if node.key?('schemaname')
      output << format('AUTHORIZATION %s', deparse_item(node['authrole'])) if node.key?('authrole')
      output << deparse_item_list(node['schemaElts']) if node.key?('schemaElts')
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

    def deparse_create_table_as(node)
      output = []
      output << 'CREATE TEMPORARY TABLE'
      output << deparse_item(node['into'])
      output << 'AS'
      output << deparse_item(node['query'])
      output.join(' ')
    end

    def deparse_into_clause(node)
      deparse_item(node['rel'])
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
        format('%s IN (%s)', deparse_item(node['testexpr']), deparse_item(node['subselect']))
      elsif node['subLinkType'] == SUBLINK_TYPE_ALL
        format('%s %s ALL (%s)', deparse_item(node['testexpr']), deparse_item(node['operName'][0], :operator), deparse_item(node['subselect']))
      elsif node['subLinkType'] == SUBLINK_TYPE_EXISTS
        format('EXISTS(%s)', deparse_item(node['subselect']))
      else
        format('(%s)', deparse_item(node['subselect']))
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

      output << deparse_item(node['withClause']) if node['withClause']

      if node['op'] == 1
        output << deparse_item(node['larg'])
        output << 'UNION'
        output << 'ALL' if node['all']
        output << deparse_item(node['rarg'])
        output.join(' ')
      end

      if node['op'] == 3
        output << deparse_item(node['larg'])
        output << 'EXCEPT'
        output << deparse_item(node['rarg'])
        output.join(' ')
      end

      if node[TARGET_LIST_FIELD]
        output << 'SELECT'
        if node['distinctClause']
          output << 'DISTINCT'
          unless node['distinctClause'].compact.empty?
            columns = node['distinctClause'].map { |item| deparse_item(item, :select) }
            output << "ON (#{columns.join(', ')})"
          end
        end
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

    def deparse_sql_value_function(node)
      output = []
      lookup = [
        'current_date',
        'current_time',
        'current_time', # with precision
        'current_timestamp',
        'current_timestamp', # with precision
        'localtime',
        'localtime', # with precision
        'localtimestamp',
        'localtimestamp', # with precision
        'current_role',
        'current_user',
        'session_user',
        'user',
        'current_catalog',
        'current_schema'
      ]
      output << lookup[node['op']]
      output << "(#{node['typmod']})" unless node.fetch('typmod', -1) == -1
      output.join('')
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
        columns = node[TARGET_LIST_FIELD].map do |item|
          deparse_item(item, :update)
        end
        output << columns.join(', ')
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
      return deparse_interval_type(node) if names == %w[pg_catalog interval]

      output = []
      output << 'SETOF' if node['setof']

      if node['typmods']
        arguments = node['typmods'].map do |item|
          deparse_item(item)
        end.join(', ')
      end
      output << deparse_typename_cast(names, arguments)
      output.last << '[]' if node['arrayBounds']

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
        arguments.nil? ? 'varchar' : "varchar(#{arguments})"
      when 'numeric'
        # numeric(3, 5)
        arguments.nil? ? 'numeric' : "numeric(#{arguments})"
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
        'double precision'
      when 'time'
        'time'
      when 'timetz'
        'time with time zone'
      when 'timestamp'
        'timestamp'
      when 'timestamptz'
        'timestamp with time zone'
      else
        raise format("Can't deparse type: %s", type)
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
      case node['nulltesttype']
      when 0
        output << 'IS NULL'
      when 1
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
    }.freeze
    def deparse_transaction(node)
      output = []
      output << TRANSACTION_CMDS[node['kind']] || raise(format("Can't deparse TRANSACTION %s", node.inspect))

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

    def deparse_define_stmt(node)
      dispatch = {
        1 => :deparse_create_aggregate,
        25 => :deparse_create_operator,
        45 => :deparse_create_type
      }
      method(dispatch.fetch(node['kind'])).call(node)
    end

    def deparse_create_aggregate(node)
      output = ['CREATE AGGREGATE']
      output << node['defnames'].map(&method(:deparse_item))
      args = node['args'][0] || [{ A_STAR => nil }]
      output << "(#{args.map(&method(:deparse_item)).join(', ')})"
      definitions = node['definition'].map do |definition|
        definition_output = [definition['DefElem']['defname']]
        definition_output << definition['DefElem']['arg']['TypeName']['names'].map(&method(:deparse_item)).join(', ') if definition['DefElem'].key?('arg')
        definition_output.join('=')
      end
      output << "(#{definitions.join(', ')})"
      output.join(' ')
    end

    def deparse_create_operator(node)
      output = ['CREATE OPERATOR']
      output << node['defnames'][0]['String']['str']
      definitions = node['definition'].map do |definition|
        definition_output = [definition['DefElem']['defname']]
        definition_output << definition['DefElem']['arg']['TypeName']['names'].map(&method(:deparse_item)).join(', ') if definition['DefElem'].key?('arg')
        definition_output.join('=')
      end
      output << "(#{definitions.join(', ')})"
      output.join(' ')
    end

    def deparse_create_type(node)
      output = ['CREATE TYPE']
      output << node['defnames'].map(&method(:deparse_item))
      if node.key?('definition')
        definitions = node['definition'].map do |definition|
          definition_output = [definition['DefElem']['defname']]
          if definition['DefElem'].key?('arg')
            definition_output += definition['DefElem']['arg']['TypeName']['names'].map(&method(:deparse_item))
          end
          definition_output.join('=')
        end
        output << "(#{definitions.join(', ')})"
      end
      output.join(' ')
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

    def deparse_discard(node)
      output = ['DISCARD']
      output << 'ALL' if (node['target']).zero?
      output << 'PLANS' if node['target'] == 1
      output << 'SEQUENCES' if node['target'] == 2
      output << 'TEMP' if node['target'] == 3
      output.join(' ')
    end

    def deparse_drop(node) # rubocop:disable Metrics/CyclomaticComplexity
      output = ['DROP']
      output << 'TABLE' if node['removeType'] == OBJECT_TYPE_TABLE
      output << 'SCHEMA' if node['removeType'] == OBJECT_TYPE_SCHEMA
      output << 'CONCURRENTLY' if node['concurrent']
      output << 'IF EXISTS' if node['missing_ok']

      objects = node['objects']
      objects = [objects] unless objects[0].is_a?(Array)
      output << objects.map { |list| list.map { |object| deparse_item(object) } }.join(', ')

      output << 'CASCADE' if node['behavior'] == 1

      output.join(' ')
    end

    def deparse_explain(node)
      output = ['EXPLAIN']
      options = node.fetch('options', []).map { |option| option['DefElem']['defname'].upcase }
      if options.size == 1
        output.concat(options)
      elsif options.size > 1
        output << "(#{options.join(', ')})"
      end
      output << deparse_item(node['query'])
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
