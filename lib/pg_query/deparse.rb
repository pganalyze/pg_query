require_relative 'deparse/interval'
require_relative 'deparse/alter_table'
class PgQuery
  # Reconstruct all of the parsed queries into their original form
  def deparse(tree = @parsetree)
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
      when 'AEXPR AND'
        deparse_aexpr_and(node)
      when 'AEXPR ANY'
        deparse_aexpr_any(node)
      when 'AEXPR IN'
        deparse_aexpr_in(node)
      when 'AEXPR NOT'
        deparse_aexpr_not(node)
      when 'AEXPR OR'
        deparse_aexpr_or(node)
      when 'AEXPR'
        deparse_aexpr(node, context)
      when 'ALIAS'
        deparse_alias(node)
      when 'ALTER TABLE'
        deparse_alter_table(node)
      when 'ALTER TABLE CMD'
        deparse_alter_table_cmd(node)
      when 'A_ARRAYEXPR'
        deparse_a_arrayexp(node)
      when 'A_CONST'
        deparse_a_const(node)
      when 'A_INDICES'
        deparse_a_indices(node)
      when 'A_INDIRECTION'
        deparse_a_indirection(node)
      when 'A_STAR'
        deparse_a_star(node)
      when 'A_TRUNCATED'
        '...' # pg_query internal
      when 'CASE'
        deparse_case(node)
      when 'COALESCE'
        deparse_coalesce(node)
      when 'COLUMNDEF'
        deparse_columndef(node)
      when 'COLUMNREF'
        deparse_columnref(node)
      when 'COMMONTABLEEXPR'
        deparse_cte(node)
      when 'CONSTRAINT'
        deparse_constraint(node)
      when 'CREATEFUNCTIONSTMT'
        deparse_create_function(node)
      when 'CREATESTMT'
        deparse_create_table(node)
      when 'DEFELEM'
        deparse_defelem(node)
      when 'DELETE FROM'
        deparse_delete_from(node)
      when 'DROP'
        deparse_drop(node)
      when 'FUNCCALL'
        deparse_funccall(node)
      when 'FUNCTIONPARAMETER'
        deparse_functionparameter(node)
      when 'INSERT INTO'
        deparse_insert_into(node)
      when 'JOINEXPR'
        deparse_joinexpr(node)
      when 'NULLTEST'
        deparse_nulltest(node)
      when 'PARAMREF'
        deparse_paramref(node)
      when 'RANGEFUNCTION'
        deparse_range_function(node)
      when 'RANGESUBSELECT'
        deparse_rangesubselect(node)
      when 'RANGEVAR'
        deparse_rangevar(node)
      when 'RENAMESTMT'
        deparse_renamestmt(node)
      when 'RESTARGET'
        deparse_restarget(node, context)
      when 'ROW'
        deparse_row(node)
      when 'SELECT'
        deparse_select(node)
      when 'SORTBY'
        deparse_sortby(node)
      when 'SUBLINK'
        deparse_sublink(node)
      when 'TRANSACTION'
        deparse_transaction(node)
      when 'TYPECAST'
        deparse_typecast(node)
      when 'TYPENAME'
        deparse_typename(node)
      when 'UPDATE'
        deparse_update(node)
      when 'WHEN'
        deparse_when(node)
      when 'WINDOWDEF'
        deparse_windowdef(node)
      when 'WITHCLAUSE'
        deparse_with_clause(node)
      when 'VIEWSTMT'
        deparse_viewstmt(node)
      else
        fail format("Can't deparse: %s: %s", type, node.inspect)
      end
    end

    def deparse_rangevar(node)
      output = []
      output << 'ONLY' if node['inhOpt'] == 0
      output << node['relname']
      output << deparse_item(node['alias']) if node['alias']
      output.join(' ')
    end

    def deparse_renamestmt(node)
      output = []

      if node['renameType'] == 26 # table
        output << 'ALTER TABLE'
        output << deparse_item(node['relation'])
        output << 'RENAME TO'
        output << node['newname']
      end

      output.join(' ')
    end

    def deparse_columnref(node)
      node['fields'].map do |field|
        field.is_a?(String) ? field : deparse_item(field)
      end.join('.')
    end

    def deparse_a_arrayexp(node)
      'ARRAY[' + node['elements'].map do |element|
        deparse_item(element)
      end.join(', ') + ']'
    end

    def deparse_a_const(node)
      node['val'].inspect.gsub("'", "''").gsub('"', "'")
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
        name + '(' + node['colnames'].join(', ') + ')'
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
      if node['number'] == 0
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

      name = (node['funcname'] - ['pg_catalog']).join('.')
      output << format('%s(%s)', name, args.join(', '))
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
      format('%s IN (%s)', deparse_item(node['lexpr']), rexpr.join(', '))
    end

    def deparse_aexpr_not(node)
      format('NOT %s', deparse_item(node['rexpr']))
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
      output = output.join(' ' + node['name'][0] + ' ')
      if context
        # This is a nested expression, add parentheses.
        output = '(' + output + ')'
      end
      output
    end

    def deparse_aexpr_and(node)
      # Only put parantheses around OR nodes that are inside this one
      lexpr = format(['AEXPR OR'].include?(node['lexpr'].keys[0]) ? '(%s)' : '%s', deparse_item(node['lexpr']))
      rexpr = format(['AEXPR OR'].include?(node['rexpr'].keys[0]) ? '(%s)' : '%s', deparse_item(node['rexpr']))
      format('%s AND %s', lexpr, rexpr)
    end

    def deparse_aexpr_or(node)
      # Put parantheses around AND + OR nodes that are inside
      lexpr = format(['AEXPR AND', 'AEXPR OR'].include?(node['lexpr'].keys[0]) ? '(%s)' : '%s', deparse_item(node['lexpr']))
      rexpr = format(['AEXPR AND', 'AEXPR OR'].include?(node['rexpr'].keys[0]) ? '(%s)' : '%s', deparse_item(node['rexpr']))
      format('%s OR %s', lexpr, rexpr)
    end

    def deparse_aexpr_any(node)
      output = []
      output << deparse_item(node['lexpr'])
      output << format('ANY(%s)', deparse_item(node['rexpr']))
      output.join(' ' + node['name'][0] + ' ')
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
      output << node['view']['RANGEVAR']['relname']
      output << format('(%s)', node['aliases'].join(', ')) if node['aliases']

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

    def deparse_cte(node)
      output = []
      output << node['ctename']
      output << format('(%s)', node['aliascolnames'].join(', ')) if node['aliascolnames']
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

    def deparse_constraint(node)
      output = []
      if node['conname']
        output << 'CONSTRAINT'
        output << node['conname']
      end
      # NOT_NULL -> NOT NULL
      output << node['contype'].gsub('_', ' ')

      if node['raw_expr']
        expression = deparse_item(node['raw_expr'])
        # Unless it's simple, put parentheses around it
        expression = '(' + expression + ')' if node['raw_expr'].keys == ['AEXPR']
        output << expression
      end
      output << '(' + node['keys'].join(', ') + ')' if node['keys']
      output << "USING INDEX #{node['indexname']}" if node['indexname']
      output.join(' ')
    end

    def deparse_create_function(node)
      output = []
      output << 'CREATE FUNCTION'

      arguments = node['parameters'].map { |item| deparse_item(item) }.join(', ')

      output << node['funcname'].first + '(' + arguments + ')'

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
      if node['subLinkType'] == 2 && node['operName'] == ['=']
        return format('%s IN (%s)', deparse_item(node['testexpr']), deparse_item(node['subselect']))
      elsif node['subLinkType'] == 0
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

      if node['targetList']
        output << 'SELECT'
        output << node['targetList'].map do |item|
          deparse_item(item, :select)
        end.join(', ')
      end

      if node['fromClause']
        output << 'FROM'
        output << node['fromClause'].map do |item|
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

      if node['targetList']
        output << 'SET'
        node['targetList'].each do |item|
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
        deparse_item(node['arg']) + '::' + deparse_typename(node['typeName']['TYPENAME'])
      end
    end

    def deparse_typename(node)
      # Intervals are tricky and should be handled in a separate method because
      # they require performing some bitmask operations.
      return deparse_interval_type(node) if node['names'] == %w(pg_catalog interval)

      output = []
      output << 'SETOF' if node['setof']

      if node['typmods']
        arguments = node['typmods'].map do |item|
          deparse_item(item)
        end.join(', ')
      end
      output << deparse_typename_cast(node['names'], arguments)

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
      0 => 'BEGIN',
      2 => 'COMMIT',
      3 => 'ROLLBACK',
      4 => 'SAVEPOINT',
      5 => 'RELEASE',
      6 => 'ROLLBACK TO SAVEPOINT'
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
        "AS $$#{node['arg'].join("\n")}$$"
      when 'language'
        "language #{node['arg']}"
      else
        node['arg']
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
      output << 'TABLE' if node['removeType'] == 26
      output << 'CONCURRENTLY' if node['concurrent']
      output << 'IF EXISTS' if node['missing_ok']

      output << node['objects'].join(', ')

      output << 'CASCADE'  if node['behavior'] == 1

      output.join(' ')
    end

    # The PG parser adds several pieces of view data onto the RANGEVAR
    # that need to be printed before deparse_rangevar is called.
    def relpersistence(rangevar)
      if rangevar['RANGEVAR']['relpersistence'] == 't'
        'TEMPORARY'
      elsif rangevar['RANGEVAR']['relpersistence'] == 'u'
        'UNLOGGED'
      end
    end
  end
end
